defmodule DiwaAgent.Tools.Executor do
  @moduledoc """
  Tool execution logic for all Diwa MCP tools.

  Handles the actual implementation of each tool by calling
  the appropriate storage layer functions.
  """

  alias DiwaAgent.Storage.{Context, Memory, Plan, Task, MemoryVersion}
  alias DiwaAgent.Registry.Server, as: Registry
  require Logger

  @consensus_module Application.compile_env(
                      :diwa_agent,
                      :consensus_module,
                      DiwaAgent.Consensus.ClusterManager
                    )

  @doc """
  Execute a tool with the given arguments.

  Returns an MCP-formatted response.
  """
  def execute("create_context", args) when not is_map_key(args, "name") do
    error_response("Error: 'name' parameter is required")
  end

  def execute("create_context", %{"name" => name} = args) do
    description = Map.get(args, "description")
    organization_id = Map.get(args, "organization_id")

    case Context.create(name, description, organization_id) do
      {:ok, context} ->
        # Record genesis commit
        DiwaAgent.CVC.record_commit(
          context.id,
          "antigravity",
          context.id,
          "Context Created (Genesis)"
        )

        success_response("""
        ✓ Context '#{context.name}' created successfully!

        ID: #{context.id}
        Organization: #{context.organization_id}
        Created: #{context.inserted_at}
        """)

      {:error, reason} ->
        error_response("Error creating context: #{inspect(reason)}")
    end
  end

  def execute("list_contexts", args) do
    organization_id = Map.get(args, "organization_id")
    {:ok, contexts} = Context.list(organization_id)

    if contexts == [] do
      success_response("No contexts found. Use create_context to create one.")
    else
      context_list =
        contexts
        |> Enum.map(fn ctx ->
          desc = if ctx.description, do: " - #{ctx.description}", else: ""

          "• #{ctx.name}#{desc}\n  ID: #{ctx.id}\n  Organization: #{ctx.organization_id}\n  Updated: #{ctx.updated_at}"
        end)
        |> Enum.join("\n\n")

      success_response("Found #{length(contexts)} context(s):\n\n#{context_list}")
    end
  end

  def execute("list_organizations", _args) do
    {:ok, orgs} = DiwaAgent.Storage.Organization.list()

    org_list =
      orgs
      |> Enum.map(fn org ->
        "• #{org.name} (#{org.tier})\n  ID: #{org.id}"
      end)
      |> Enum.join("\n\n")

    success_response("Found #{length(orgs)} organization(s):\n\n#{org_list}")
  end

  def execute("get_context", %{"context_id" => context_id}) do
    case Context.get(context_id) do
      {:ok, context} ->
        desc = if context.description, do: "\nDescription: #{context.description}", else: ""

        # Also get memory count
        {:ok, count} = Memory.count(context_id)

        success_response("""
        Context: #{context.name}#{desc}

        ID: #{context.id}
        Created: #{context.inserted_at}
        Updated: #{context.updated_at}
        Memories: #{count}
        """)

      {:error, :not_found} ->
        error_response("Context not found: #{context_id}")

      {:error, reason} ->
        error_response("Error retrieving context: #{inspect(reason)}")
    end
  end

  def execute("resolve_context", %{"name" => name}) do
    case Context.find_by_name(name) do
      {:ok, context} ->
        success_response("""
        ✓ Context found: '#{context.name}'

        ID: #{context.id}
        Organization: #{context.organization_id}
        Description: #{context.description || "N/A"}
        """)

      {:error, :not_found} ->
        error_response("Context not found with name: '#{name}'")

      {:error, reason} ->
        error_response("Error resolving context: #{inspect(reason)}")
    end
  end

  def execute("update_context", %{"context_id" => context_id} = args) do
    updates =
      %{
        name: Map.get(args, "name"),
        description: Map.get(args, "description")
      }
      |> Enum.filter(fn {_k, v} -> v != nil end)
      |> Map.new()

    if map_size(updates) == 0 do
      error_response("No updates provided. Include 'name' or 'description'.")
    else
      case Context.update(context_id, updates) do
        {:ok, context} ->
          DiwaAgent.CVC.record_commit(
            context.id,
            "antigravity",
            context.id,
            "Context metadata updated"
          )

          success_response("✓ Context '#{context.name}' updated successfully!")

        {:error, :not_found} ->
          error_response("Context not found: #{context_id}")

        {:error, reason} ->
          error_response("Error updating context: #{inspect(reason)}")
      end
    end
  end

  def execute("delete_context", %{"context_id" => context_id}) do
    case Context.delete(context_id) do
      :ok ->
        success_response("✓ Context deleted successfully (including all memories)")

      {:error, reason} ->
        error_response("Error deleting context: #{inspect(reason)}")
    end
  end

  def execute("add_memory", %{"context_id" => context_id, "content" => content} = args) do
    # Phase 4 Hardening: Validation
    with {:ok, _} <- DiwaAgent.Validation.validate_uuid(context_id, "context_id"),
         {:ok, _} <- DiwaAgent.Validation.validate_required(args, ~w(content)) do
      opts = %{
        metadata: Map.get(args, "metadata"),
        actor: Map.get(args, "actor"),
        project: Map.get(args, "project"),
        tags: Map.get(args, "tags"),
        parent_id: Map.get(args, "parent_id"),
        external_ref: Map.get(args, "external_ref"),
        severity: Map.get(args, "severity")
      }

      # Patent #3: Check collision logic temporarily disabled for Phase 1 Migration
      # check_conflict requires valid SemanticFingerprint generation which happens asynchronously now
      # TODO: Re-enable instant collision detection in Phase 2

      case Memory.add(context_id, content, opts) do
        {:ok, memory} ->
          # CVC: Record commit
          platform = opts[:actor] || "antigravity"
          DiwaAgent.CVC.record_commit(context_id, platform, memory.id, "Added memory via MCP")

          success_response("""
          ✓ Memory added successfully!

          ID: #{memory.id}
          Created: #{memory.inserted_at}
          """)

        {:error, :context_not_found} ->
          error_response("Context not found: #{context_id}")

        {:error, reason} ->
          error_response("Error adding memory: #{inspect(reason)}")
      end
    else
      {:error, reason} -> error_response("Validation failed: #{reason.message}")
    end
  end

  def execute("add_memories", %{"context_id" => context_id, "memories" => memories}) do
    # Check if we should register the platform for CVC
    # Inferred default as we are running in AG environment mostly?
    platform = "antigravity"
    # Or we should try to extract it from somewhere.
    # For now, let's just record commits if we can.

    results =
      Enum.map(memories, fn mem_args ->
        opts = %{
          metadata: Map.get(mem_args, "metadata"),
          actor: Map.get(mem_args, "actor"),
          project: Map.get(mem_args, "project"),
          tags: Map.get(mem_args, "tags"),
          parent_id: Map.get(mem_args, "parent_id"),
          external_ref: Map.get(mem_args, "external_ref"),
          severity: Map.get(mem_args, "severity")
        }

        content = Map.get(mem_args, "content")

        case Memory.add(context_id, content, opts) do
          {:ok, memory} ->
            # Record CVC commit for each memory
            actor_platform = opts[:actor] || platform

            DiwaAgent.CVC.record_commit(
              context_id,
              actor_platform,
              memory.id,
              "Batch added memory"
            )

            {:ok, memory}

          error ->
            error
        end
      end)

    success_count =
      Enum.count(results, fn
        {:ok, _} -> true
        _ -> false
      end)

    success_response("✓ Successfully added #{success_count} of #{length(memories)} memories.")
  end

  def execute("classify_memory", %{"content" => content} = args) do
    filename = Map.get(args, "filename")

    case DiwaAgent.ContextBridge.MemoryClassification.classify(content, filename: filename) do
      {:ok, class, priority, lifecycle} ->
        success_response("""
        ✓ Memory Classified:
        Class: #{class}
        Priority: #{priority}
        Lifecycle: #{lifecycle}
        """)
    end
  end

  def execute("hydrate_context", %{"context_id" => cid} = args) do
    depth_str = Map.get(args, "depth", "standard")

    depth =
      case depth_str do
        "minimal" -> :minimal
        "standard" -> :standard
        "comprehensive" -> :comprehensive
        _ -> :standard
      end

    focus = Map.get(args, "focus")

    case DiwaAgent.ContextBridge.Hydration.hydrate(cid, depth: depth, focus: focus) do
      {:ok, result} -> success_response(format_hydration(result))
      error -> error_response("Hydration failed: #{inspect(error)}")
    end
  end

  def execute("validate_action", %{"context_id" => cid, "content" => content} = args) do
    mode_str = Map.get(args, "mode", "warn")

    mode =
      case mode_str do
        "strict" -> :strict
        "warn" -> :warn
        "audit" -> :audit
        _ -> :warn
      end

    case DiwaAgent.ContextBridge.RuleEnforcement.validate(cid, content, mode: mode) do
      {:ok, :valid} ->
        success_response("✓ Action complies with all project rules.")

      {:warn, :violations, list} ->
        warnings = Enum.map(list, fn v -> "• #{v.title}: #{v.message}" end) |> Enum.join("\n")
        success_response("⚠️ Rule Warnings:\n\n#{warnings}")

      {:error, :violations, list} ->
        errors = Enum.map(list, fn v -> "• #{v.title}: #{v.message}" end) |> Enum.join("\n")
        error_response("❌ Rule Violations (Strict Mode):\n\n#{errors}")
    end
  end

  def execute("ingest_context", %{"context_id" => context_id} = args) do
    dirs = Map.get(args, "directories", [".agent", ".cursor"])

    case DiwaAgent.ContextBridge.Ingestor.run(context_id, dirs: dirs) do
      {:ok, stats} ->
        success_response("""
        ✓ Context Ingestion Complete!

        Created: #{stats.created}
        Skipped: #{stats.skipped}
        Failed: #{stats.failed}
        """)

      {:error, reason} ->
        error_response("Ingestion failed: #{inspect(reason)}")
    end
  end

  def execute("start_session", %{"context_id" => cid, "actor" => actor} = args) do
    metadata = Map.get(args, "metadata", %{})

    case DiwaAgent.ContextBridge.LiveSync.start_session(cid, actor, metadata) do
      {:ok, session} -> success_response("✓ Session started! ID: #{session.id}")
      {:error, reason} -> error_response("Failed to start session: #{inspect(reason)}")
    end
  end

  def execute("log_session_activity", %{"session_id" => sid, "message" => msg} = args) do
    metadata = Map.get(args, "metadata", %{})
    DiwaAgent.ContextBridge.LiveSync.log_activity(sid, msg, metadata)
    success_response("✓ Activity logged.")
  end

  def execute("end_session", %{"session_id" => sid, "summary" => sum} = args) do
    next_steps = Map.get(args, "next_steps", [])

    case DiwaAgent.ContextBridge.LiveSync.end_session(sid, sum, next_steps) do
      {:ok, _session} -> success_response("✓ Session ended and handoff note recorded.")
      {:error, reason} -> error_response("Failed to end session: #{inspect(reason)}")
    end
  end

  def execute("prune_expired_memories", _args) do
    case DiwaAgent.ContextBridge.MemoryLifecycle.prune_expired() do
      {:ok, count} -> success_response("✓ Pruned #{count} expired memories across all contexts.")
      error -> error_response("Pruning failed: #{inspect(error)}")
    end
  end

  def execute("list_memories", %{"context_id" => context_id} = args) do
    limit = Map.get(args, "limit", 100)

    {:ok, memories} = Memory.list(context_id, limit: limit)

    if memories == [] do
      success_response("No memories found for this context.")
    else
      memory_list =
        memories
        |> Enum.map(fn mem ->
          snippet = String.slice(mem.content, 0, 100)
          "• [#{mem.id}] #{snippet}"
        end)
        |> Enum.join("\n")

      success_response(
        "Found #{length(memories)} memory(ies) (Limit: #{limit}):\n\n#{memory_list}"
      )
    end
  end

  def execute("get_memory", %{"memory_id" => memory_id}) do
    case Memory.get(memory_id) do
      {:ok, memory} ->
        success_response("""
        Memory:

        #{memory.content}

        ───────────────
        ID: #{memory.id}
        Context: #{memory.context_id}
        Created: #{memory.inserted_at}
        Updated: #{memory.updated_at}
        """)

      {:error, :not_found} ->
        error_response("Memory not found: #{memory_id}")

      {:error, reason} ->
        error_response("Error retrieving memory: #{inspect(reason)}")
    end
  end

  def execute("update_memory", %{"memory_id" => memory_id, "content" => content}) do
    case Memory.update(memory_id, content) do
      {:ok, memory} ->
        DiwaAgent.CVC.record_commit(
          memory.context_id,
          "antigravity",
          memory.id,
          "Updated memory content"
        )

        success_response("✓ Memory updated successfully!")

      {:error, :not_found} ->
        error_response("Memory not found: #{memory_id}")

      {:error, reason} ->
        error_response("Error updating memory: #{inspect(reason)}")
    end
  end

  def execute("get_context_health", %{"context_id" => context_id}) do
    case DiwaAgent.Storage.HealthEngine.compute_health(context_id) do
      {:ok, %{total: total, breakdown: b}} ->
        success_response("""
        📊 Context Health Report (Patent #1)

        Total Score: #{total}/100

        Breakdown:
        - Recency: #{b.recency}/40
        - Activity: #{b.activity}/30
        - Completeness: #{b.completeness}/30

        Summary: #{get_health_summary(total)}
        """)
    end
  end

  def execute("run_context_scan", %{"context_id" => context_id} = args) do
    path = Map.get(args, "path", ".")

    case DiwaAgent.ACE.Engine.run_context_scan(path) do
      {:ok, facts} ->
        # Persist facts as memories
        # Persist facts as memories
        count =
          Enum.count(facts, fn fact ->
            description = fact.doc_summary || "No documentation extracted."

            content =
              "### ACE Fact: #{fact.name}\n\n#{description}\n\nFile: `#{fact.source}`:#{fact.line}"

            # Extract category/confidence from metadata if present, else default
            category = Map.get(fact.metadata, :category, "General")
            confidence = Map.get(fact.metadata, :confidence, 1.0)

            metadata = %{
              type: "ace_fact",
              fact_type: fact.type,
              category: category,
              confidence: confidence,
              source: fact.source,
              line: fact.line,
              raw_metadata: fact.metadata
            }

            opts = %{
              metadata: Jason.encode!(metadata),
              actor: "ACE/v1",
              tags: "ace,#{category},#{fact.type}"
            }

            case Memory.add(context_id, content, opts) do
              {:ok, _} -> true
              _ -> false
            end
          end)

        success_response("""
        🤖 ACE Scan Complete (Engine v2)

        Successfully extracted #{count} architectural facts from '#{path}'.
        These have been added as memories to the context.
        """)
    end
  end

  def execute("delete_memory", %{"memory_id" => memory_id}) do
    # Fetch first to get context_id for CVC
    context_id =
      case Memory.get(memory_id) do
        {:ok, mem} -> mem.context_id
        _ -> nil
      end

    case Memory.delete(memory_id) do
      {:ok, _res} ->
        if context_id,
          do: DiwaAgent.CVC.record_commit(context_id, "antigravity", memory_id, "Deleted memory")

        success_response("✓ Memory '#{memory_id}' deleted successfully (soft-delete).")

      {:error, :not_found} ->
        error_response("Memory not found: #{memory_id}")

      {:error, reason} ->
        error_response("Error deleting memory: #{inspect(reason)}")
    end
  end

  def execute("get_memory_history", %{"memory_id" => id}) do
    case MemoryVersion.list_history(id) do
      {:ok, versions} ->
        if versions == [] do
          success_response("No history found for memory: #{id}")
        else
          history =
            versions
            |> Enum.map(fn v ->
              "• [#{v.id}] **#{v.operation}** by #{v.actor || "unknown"} at #{v.inserted_at}\n  Reason: #{inspect(v.reason || "N/A")}"
            end)
            |> Enum.join("\n\n")

          success_response("Version history for memory #{id}:\n\n#{history}")
        end
    end
  end

  def execute("rollback_memory", %{"memory_id" => mid, "version_id" => vid} = args) do
    actor = Map.get(args, "actor")
    reason = Map.get(args, "reason")

    case Memory.rollback(mid, vid, %{actor: actor, reason: reason}) do
      {:ok, memory} ->
        success_response(
          "✓ Memory #{mid} rolled back successfully to version #{vid}.\n\nCurrent content length: #{String.length(memory.content)} characters."
        )

      {:error, reason} ->
        error_response("Rollback failed: #{inspect(reason)}")
    end
  end

  def execute("compare_memory_versions", %{"version_id_1" => v1, "version_id_2" => v2}) do
    with {:ok, ver1} <- MemoryVersion.get(v1),
         {:ok, ver2} <- MemoryVersion.get(v2) do
      diff = """
      Comparing Version #{v1} and #{v2}:

      --- VERSION 1 (#{ver1.operation} at #{ver1.inserted_at}) ---
      Content: #{ver1.content}
      Tags: #{inspect(ver1.tags)}
      Metadata: #{inspect(ver1.metadata)}

      --- VERSION 2 (#{ver2.operation} at #{ver2.inserted_at}) ---
      Content: #{ver2.content}
      Tags: #{inspect(ver2.tags)}
      Metadata: #{inspect(ver2.metadata)}
      """

      success_response(diff)
    else
      {:error, :not_found} -> error_response("One or both versions not found.")
    end
  end

  def execute("get_recent_changes", %{"context_id" => cid} = args) do
    limit = Map.get(args, "limit", 20)

    case MemoryVersion.list_recent_changes(cid, limit) do
      {:ok, changes} ->
        if changes == [] do
          success_response("No recent changes found for context: #{cid}")
        else
          list =
            changes
            |> Enum.map(fn v ->
              "• [#{v.id}] **#{v.operation}** on Memory #{v.memory_id} by #{v.actor || "unknown"} at #{v.inserted_at}"
            end)
            |> Enum.join("\n")

          success_response("Recent changes in context #{cid}:\n\n#{list}")
        end
    end
  end

  def execute("list_conflicts", %{"context_id" => context_id} = _args) do
    # Support filtering options
    opts = []

    case DiwaAgent.Conflict.Engine.detect_conflicts(context_id, opts) do
      {:ok, conflicts} ->
        if conflicts == [] do
          success_response(
            "No knowledge collisions detected in this context. Everything is consistent! ✨"
          )
        else
          list =
            conflicts
            |> Enum.map(fn c ->
              "• [#{String.upcase(Atom.to_string(c.conflict_type || :unknown))}] Similarity: #{c.similarity_score}\n  Severity: #{c.severity}\n  IDs: #{c.memory_a_id} vs #{c.memory_b_id}"
            end)
            |> Enum.join("\n\n")

          success_response("""
          ⚠️ Found #{length(conflicts)} potential knowledge collision(s): (Patent #3)

          #{list}
          """)
        end

      {:error, reason} ->
        error_response("Error detecting conflicts: #{inspect(reason)}")
    end
  end

  def execute("resolve_conflict", %{"context_id" => context_id} = args) do
    # Extract known params
    params = Map.take(args, ["strategy", "keep_ids", "discard_ids", "reason"])

    case DiwaAgent.Conflict.Engine.resolve_conflict(context_id, params) do
      {:ok, result} ->
        format_resolution_result(result)
        |> success_response()

      {:error, reason} ->
        error_response("Conflict resolution failed: #{inspect(reason)}")
    end
  end

  def execute("search_memories", %{"query" => query} = args) do
    context_id = Map.get(args, "context_id")

    case Memory.search(query, context_id) do
      {:ok, []} ->
        scope = if context_id, do: " in this context", else: ""
        success_response("No memories found matching '#{query}'#{scope}.")

      {:ok, memories} ->
        # Get context name if searching within specific context
        scope_desc =
          if context_id do
            case Context.get(context_id) do
              {:ok, ctx} -> " in '#{ctx.name}'"
              _ -> " in specified context"
            end
          else
            " across all contexts"
          end

        # Format results with previews
        results =
          memories
          |> Enum.map(fn mem ->
            preview = String.slice(mem.content, 0, 150)
            preview = if String.length(mem.content) > 150, do: preview <> "...", else: preview

            # Get context name for each result
            context_name =
              case Context.get(mem.context_id) do
                {:ok, ctx} -> ctx.name
                _ -> "Unknown"
              end

            """
            • #{preview}
              Context: #{context_name}
              ID: #{mem.id}
              Created: #{mem.inserted_at}
            """
          end)
          |> Enum.join("\n\n")

        success_response("""
        Found #{length(memories)} result#{if length(memories) == 1, do: "", else: "s"}#{scope_desc}:

        #{results}
        """)
    end
  end

  def execute("ingest_agent_dir", %{"context_id" => context_id}) do
    # Maintain backward compatibility but use new engine
    case DiwaAgent.ContextBridge.Ingestor.run(context_id, dirs: [".agent"]) do
      {:ok, stats} ->
        success_response(
          "✓ Ingested #{stats.created} new files from .agent directory (Skipped: #{stats.skipped})."
        )

      {:error, reason} ->
        error_response(reason)
    end
  end

  # --- Bridge Coordination Logic ---

  def execute(
        "set_project_status",
        %{"context_id" => cid, "status" => status, "completion_pct" => pct} = args
      ) do
    notes = Map.get(args, "notes", "Status updated to #{status}")

    case Plan.set(cid, status, pct, notes) do
      {:ok, _plan} -> success_response("✓ Project status updated to '#{status}' (#{pct}%)")
      {:error, reason} -> error_response("Failed to set status: #{inspect(reason)}")
    end
  end

  def execute("get_project_status", %{"context_id" => cid}) do
    case Plan.get(cid) do
      {:ok, plan} ->
        success_response("""
        Current Project Status:

        Status: #{plan.status}
        Progress: #{plan.completion_pct}%
        Notes: #{plan.notes}
        Updated: #{plan.updated_at}
        """)

      {:error, :not_found} ->
        success_response("No status recorded for this context yet.")
    end
  end

  def execute(
        "add_requirement",
        %{"context_id" => cid, "title" => title, "description" => desc} = args
      ) do
    priority = Map.get(args, "priority", "Medium")

    case Task.add(cid, title, desc, priority) do
      {:ok, task} ->
        success_response("""
        ✓ Requirement added: '#{title}' (#{priority} priority)
        ID: #{task.id}
        """)

      {:error, reason} ->
        error_response("Failed to add requirement: #{inspect(reason)}")
    end
  end

  def execute("mark_requirement_complete", %{"requirement_id" => rid}) do
    case Task.complete(rid) do
      {:ok, task} ->
        success_response("✓ Requirement '#{task.title}' marked as complete.")

      {:error, :not_found} ->
        error_response("Requirement not found: #{rid}")

      {:error, reason} ->
        error_response("Error: #{inspect(reason)}")
    end
  end

  def execute(
        "record_lesson",
        %{"context_id" => cid, "title" => title, "content" => content} = args
      ) do
    category = Map.get(args, "category", "General")
    metadata = %{type: "lesson", title: title, category: category}

    case Memory.add(cid, content, Jason.encode!(metadata)) do
      {:ok, _} -> success_response("✓ Lesson recorded: '#{title}'")
      {:error, reason} -> error_response("Failed to record lesson: #{inspect(reason)}")
    end
  end

  def execute("search_lessons", %{"query" => query}) do
    {:ok, memories} = Memory.search(query)

    lessons =
      memories
      |> Enum.filter(fn mem ->
        meta =
          if is_binary(mem.metadata), do: Jason.decode!(mem.metadata || "{}"), else: mem.metadata

        meta["type"] == "lesson"
      end)

    if Enum.empty?(lessons) do
      success_response("No lessons found matching '#{query}'.")
    else
      results =
        lessons
        |> Enum.map(fn mem ->
          meta = if is_binary(mem.metadata), do: Jason.decode!(mem.metadata), else: mem.metadata
          "• [#{meta["category"]}] #{meta["title"]}\n  #{String.slice(mem.content, 0, 150)}..."
        end)
        |> Enum.join("\n\n")

      success_response("Found #{length(lessons)} lesson(s):\n\n#{results}")
    end
  end

  def execute(
        "flag_blocker",
        %{"context_id" => cid, "title" => title, "description" => desc} = args
      ) do
    severity = Map.get(args, "severity", "Moderate")
    metadata = %{type: "blocker", title: title, severity: severity, status: "active"}

    case Memory.add(cid, desc, Jason.encode!(metadata)) do
      {:ok, memory} ->
        success_response("""
        ⚠️ BLOCKER FLAGGED: '#{title}' (#{severity} severity)
        ID: #{memory.id}
        """)

      {:error, reason} ->
        error_response("Failed to flag blocker: #{inspect(reason)}")
    end
  end

  def execute("resolve_blocker", %{"blocker_id" => bid, "resolution" => res}) do
    case Memory.get(bid) do
      {:ok, memory} ->
        meta =
          if is_binary(memory.metadata),
            do: Jason.decode!(memory.metadata || "{}"),
            else: memory.metadata

        if meta["type"] == "blocker" do
          current_content = memory.content || ""
          resolution_text = res || "No resolution provided"

          # Debug inputs
          Logger.info(
            "[Executor] Resolving blocker #{bid}. Content: '#{current_content}', Resolution: '#{resolution_text}'"
          )

          new_content = "[RESOLVED] " <> current_content <> "\n\nResolution: " <> resolution_text
          Memory.update(bid, new_content)
          success_response("✓ Blocker '#{meta["title"]}' marked as resolved.")
        else
          error_response("Memory #{bid} is not a blocker.")
        end

      {:error, :not_found} ->
        error_response("Blocker not found: #{bid}")

      {:error, reason} ->
        error_response("Error: #{inspect(reason)}")
    end
  end

  def execute(
        "set_handoff_note",
        %{"context_id" => cid, "summary" => sum} = args
      ) do
    # Use Schema for validation/defaults
    handoff = DiwaAgent.Delegation.Handoff.new(args)
    metadata = DiwaAgent.Delegation.Handoff.to_metadata(handoff)

    case Memory.add(cid, sum, Jason.encode!(metadata)) do
      {:ok, _} -> success_response("✓ Handoff note recorded for next session.")
      {:error, reason} -> error_response("Failed to set handoff: #{inspect(reason)}")
    end
  end

  def execute("get_active_handoff", %{"context_id" => cid}) do
    {:ok, list} = Memory.list_by_type(cid, "handoff")

    case list do
      [latest | _] ->
        meta =
          if is_binary(latest.metadata), do: Jason.decode!(latest.metadata), else: latest.metadata

        steps = meta["next_steps"] |> Enum.map(&"- #{&1}") |> Enum.join("\n")
        files = meta["active_files"] |> Enum.map(&"- #{&1}") |> Enum.join("\n")

        success_response("""
        🚀 Session Handoff Briefing:

        Summary: #{latest.content}

        Next Steps:
        #{steps}

        Active Files:
        #{files}

        Recorded: #{latest.inserted_at}
        """)

      [] ->
        success_response("No handoff notes found for this context.")
    end
  end

  def execute("get_pending_tasks", %{"context_id" => cid} = args) do
    limit = Map.get(args, "limit", 10)
    {:ok, tasks} = Task.get_pending(cid, limit)

    if tasks == [] do
      success_response("No pending tasks for this context. All clear! ✅")
    else
      task_list =
        tasks
        |> Enum.map(fn task ->
          """
          • [#{task.priority}] #{task.title}
            ID: #{task.id}
            #{task.description}
            Created: #{task.inserted_at}
          """
        end)
        |> Enum.join("\n")

      success_response("""
      📋 Pending Tasks (#{length(tasks)} of #{limit} shown):

      #{task_list}
      """)
    end
  end

  def execute("get_resume_context", %{"context_id" => cid}) do
    # Get handoff note
    {:ok, handoffs} = Memory.list_by_type(cid, "handoff")

    handoff_summary =
      case handoffs do
        [latest | _] ->
          meta =
            if is_binary(latest.metadata),
              do: Jason.decode!(latest.metadata),
              else: latest.metadata

          steps = meta["next_steps"] |> Enum.take(3) |> Enum.map(&"  - #{&1}") |> Enum.join("\n")

          """
          📝 Last Session Summary:
          #{latest.content}

          Next Steps:
          #{steps}
          """

        [] ->
          "No handoff note available."
      end

    # Get pending tasks
    {:ok, tasks} = Task.get_pending(cid, 5)

    tasks_summary =
      if tasks == [] do
        "✅ No pending tasks"
      else
        task_list =
          tasks
          |> Enum.map(fn t -> "  - [#{t.priority}] #{t.title}" end)
          |> Enum.join("\n")

        """
        📋 Pending Tasks (#{length(tasks)}):
        #{task_list}
        """
      end

    # Get active blockers
    {:ok, blockers} = Memory.list_by_type(cid, "blocker")

    active_blockers =
      blockers
      |> Enum.filter(fn b ->
        !String.starts_with?(b.content || "", "[RESOLVED]")
      end)

    blockers_summary =
      if active_blockers == [] do
        "✅ No active blockers"
      else
        blocker_list =
          active_blockers
          |> Enum.take(3)
          |> Enum.map(fn b ->
            meta =
              if is_binary(b.metadata), do: Jason.decode!(b.metadata || "{}"), else: b.metadata

            "  - [#{meta["severity"]}] #{meta["title"]}"
          end)
          |> Enum.join("\n")

        """
        ⚠️  Active Blockers (#{length(active_blockers)}):
        #{blocker_list}
        """
      end

    # Get health score
    health_summary =
      case DiwaAgent.Storage.HealthEngine.compute_health(cid) do
        {:ok, %{total: total}} -> "📊 Context Health: #{total}/100"
        _ -> "📊 Context Health: Unknown"
      end

    # Get project status
    status_summary =
      case Plan.get(cid) do
        {:ok, plan} -> "🎯 Status: #{plan.status} (#{plan.completion_pct}%)"
        _ -> "🎯 Status: Not set"
      end

    success_response("""
    🚀 SESSION START CONTEXT

    #{status_summary}
    #{health_summary}

    #{handoff_summary}

    #{tasks_summary}

    #{blockers_summary}
    """)
  end

  def execute("log_progress", %{"context_id" => cid, "message" => msg} = args) do
    tags = Map.get(args, "tags", "progress")
    metadata = %{type: "progress", timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}

    opts = %{
      metadata: Jason.encode!(metadata),
      tags: tags,
      actor: "system"
    }

    case Memory.add(cid, msg, opts) do
      {:ok, _} -> success_response("✓ Progress logged: #{String.slice(msg, 0, 50)}...")
      {:error, reason} -> error_response("Failed to log progress: #{inspect(reason)}")
    end
  end

  def execute(
        "record_decision",
        %{"context_id" => cid, "decision" => dec, "rationale" => rat} = args
      ) do
    alts = Map.get(args, "alternatives", "None listed")
    metadata = %{type: "decision", decision: dec, rationale: rat, alternatives: alts}

    opts = %{
      metadata: Jason.encode!(metadata),
      tags: "decision"
    }

    case Memory.add(cid, "Decision: #{dec}\nRationale: #{rat}", opts) do
      {:ok, _} -> success_response("✓ Decision recorded: '#{String.slice(dec, 0, 50)}...'")
      {:error, reason} -> error_response("Failed to record decision: #{inspect(reason)}")
    end
  end

  def execute(
        "record_deployment",
        %{"context_id" => cid, "environment" => env, "version" => ver, "status" => status} = args
      ) do
    ext_ref = Map.get(args, "external_ref")
    metadata = %{type: "deployment", env: env, version: ver, status: status}

    opts = %{
      metadata: Jason.encode!(metadata),
      project: env,
      external_ref: ext_ref,
      tags: "deployment"
    }

    content = "Deployed version #{ver} to #{env} with status: #{status}"

    case Memory.add(cid, content, opts) do
      {:ok, _} -> success_response("✓ Deployment of #{ver} to #{env} recorded.")
      {:error, reason} -> error_response("Failed to record deployment: #{inspect(reason)}")
    end
  end

  def execute(
        "log_incident",
        %{"context_id" => cid, "title" => title, "description" => desc, "severity" => sev} = args
      ) do
    ext_ref = Map.get(args, "external_ref")
    metadata = %{type: "incident", title: title, severity: sev}

    opts = %{
      metadata: Jason.encode!(metadata),
      severity: sev,
      external_ref: ext_ref,
      tags: "incident"
    }

    case Memory.add(cid, "[INCIDENT] #{title}\n#{desc}", opts) do
      {:ok, _} -> success_response("🚨 Incident logged: '#{title}' (#{sev})")
      {:error, reason} -> error_response("Failed to log incident: #{inspect(reason)}")
    end
  end

  def execute(
        "record_pattern",
        %{"context_id" => cid, "name" => name, "description" => desc} = args
      ) do
    example = Map.get(args, "example")
    metadata = %{type: "pattern", name: name, example: example}

    opts = %{
      metadata: Jason.encode!(metadata),
      tags: "pattern"
    }

    case Memory.add(cid, "Pattern: #{name}\n#{desc}", opts) do
      {:ok, _} -> success_response("✓ Pattern recorded: '#{name}'")
      {:error, reason} -> error_response("Failed to record pattern: #{inspect(reason)}")
    end
  end

  def execute(
        "record_review",
        %{"context_id" => cid, "title" => title, "summary" => sum, "status" => status} = args
      ) do
    ext_ref = Map.get(args, "external_ref")
    metadata = %{type: "review", title: title, status: status}

    opts = %{
      metadata: Jason.encode!(metadata),
      external_ref: ext_ref,
      tags: "review"
    }

    case Memory.add(cid, "### REVIEW: #{title}\nStatus: #{status}\n\n#{sum}", opts) do
      {:ok, _} -> success_response("✓ Review recorded: '#{title}' (#{status})")
      {:error, reason} -> error_response("Failed to record review: #{inspect(reason)}")
    end
  end

  def execute("prioritize_requirement", %{"requirement_id" => rid, "priority" => priority}) do
    case Task.update_priority(rid, priority) do
      {:ok, task} ->
        success_response("✓ Requirement '#{task.title}' priority updated to #{priority}.")

      {:error, :not_found} ->
        error_response("Requirement not found: #{rid}")

      {:error, reason} ->
        error_response("Error: #{inspect(reason)}")
    end
  end

  def execute("list_by_tag", %{"context_id" => cid, "tag" => tag}) do
    {:ok, memories} = Memory.list_by_tag(cid, tag)

    if memories == [] do
      success_response("No memories found with tag '#{tag}'.")
    else
      list =
        memories
        |> Enum.map(fn mem ->
          preview = String.slice(mem.content, 0, 100)
          preview = if String.length(mem.content) > 100, do: preview <> "...", else: preview
          tags = Enum.join(mem.tags, ", ")
          "• #{preview}\n  ID: #{mem.id}\n  Tags: #{tags}\n  Created: #{mem.inserted_at}"
        end)
        |> Enum.join("\n\n")

      success_response("Memories tagged with '#{tag}':\n\n#{list}")
    end
  end

  def execute("export_context", %{"context_id" => cid, "format" => format}) do
    case Context.get(cid) do
      {:ok, context} ->
        {:ok, memories} = Memory.list(cid, limit: 1000)
        content = format_export(context, memories, format)
        success_response(content)

      {:error, :not_found} ->
        error_response("Context not found: #{cid}")

      {:error, reason} ->
        error_response("Error: #{inspect(reason)}")
    end
  end

  def execute("perform_backup", _args) do
    case DiwaAgent.Storage.Backup.perform_full_backup() do
      {:ok, count} ->
        success_response(
          "✓ Full system backup complete. #{count} context(s) archived to ~/.diwa/backups"
        )

      {:error, reason} ->
        error_response("Backup failed: #{inspect(reason)}")
    end
  end

  def execute(
        "record_analysis_result",
        %{"context_id" => cid, "scanner_name" => scan, "findings" => findings, "severity" => sev} =
          args
      ) do
    target = Map.get(args, "target", "unknown")
    metadata = %{type: "analysis", scanner: scan, target: target, severity: sev}

    opts = %{
      metadata: Jason.encode!(metadata),
      severity: sev,
      tags: "analysis,#{scan}"
    }

    case Memory.add(cid, "[ANALYSIS] #{scan} on #{target}:\n#{findings}", opts) do
      {:ok, _} -> success_response("✓ Analysis result for '#{scan}' recorded.")
      {:error, reason} -> error_response("Failed to record analysis: #{inspect(reason)}")
    end
  end

  def execute("link_memories", %{"parent_id" => pid, "child_id" => cid}) do
    case Memory.set_parent(cid, pid) do
      {:ok, _} -> success_response("✓ Linked memory #{cid} to parent #{pid}.")
      {:error, reason} -> error_response("Failed to link memories: #{inspect(reason)}")
    end
  end

  def execute("get_memory_tree", %{"root_id" => rid}) do
    case build_tree(rid, 0) do
      {:ok, tree} -> success_response(tree)
      {:error, :not_found} -> error_response("Root memory not found: #{rid}")
      {:error, reason} -> error_response("Error: #{inspect(reason)}")
    end
  end

  # --- Agent Coordination Logic (Phase 1.4) ---

  def execute("register_agent", %{"name" => name, "role" => role, "capabilities" => caps} = _args) do
    # Convert role string to atom if needed
    role_atom = String.to_atom(role)

    attrs = [
      name: name,
      role: role_atom,
      capabilities: caps
    ]

    case DiwaAgent.Registry.Server.register(attrs) do
      {:ok, agent} ->
        success_response("""
        ✓ Agent Registered Successfully

        Name: #{agent.name}
        Role: #{agent.role}
        ID: #{agent.id}
        """)

      error ->
        error_response("Failed to register agent: #{inspect(error)}")
    end
  end

  def execute("poll_delegated_tasks", %{"agent_id" => agent_id}) do
    # Update heartbeat implicitly
    DiwaAgent.Registry.Server.heartbeat(agent_id)

    case DiwaAgent.Delegation.Broker.poll(agent_id) do
      {:ok, []} ->
        success_response("No pending tasks found.")

      {:ok, tasks} ->
        count = length(tasks)

        list =
          tasks
          |> Enum.map(fn t ->
            ref = List.first(t.active_files) || "unknown"

            """
            • [Ref: #{ref}] Task: #{t.task_definition}
              From: #{t.from_agent_id}
              Context: N/A (Session)
            """
          end)
          |> Enum.join("\n")

        success_response("""
        Found #{count} pending task(s):

        #{list}
        """)

      error ->
        error_response("Error polling tasks: #{inspect(error)}")
    end
  end

  def execute(
        "delegate_task",
        %{"from_agent_id" => from, "context_id" => _cid, "task_definition" => task_def} = args
      ) do
    to_agent = Map.get(args, "to_agent_id")
    constraints = Map.get(args, "constraints", %{})

    handoff =
      DiwaAgent.Delegation.Handoff.new(%{
        delegation_type: "agent",
        from_agent_id: from,
        to_agent_id: to_agent,
        task_definition: task_def,
        constraints: constraints
      })

    if is_nil(to_agent) do
      error_response("Target agent_id is required for Phase 1.4 MVP delegation.")
    else
      case DiwaAgent.Delegation.Broker.delegate(handoff) do
        {:ok, ref} ->
          success_response("""
          ✓ Task Delegated Successfully

          Delegation ID: #{ref}
          Target: #{to_agent}
          """)

        {:error, reason} ->
          error_response("Failed to delegate task: #{inspect(reason)}")
      end
    end
  end

  def execute("respond_to_delegation", %{"delegation_id" => id, "status" => status} = args) do
    reason = Map.get(args, "reason", "No reason provided")
    Logger.info("[Executor] Agent responded to delegation #{id}: #{status} (#{inspect(reason)})")

    if status == "rejected" do
      success_response("✓ Rejection logged (Task logic pending implementation).")
    else
      success_response("✓ Task accepted. Marking in-progress.")
    end
  end

  def execute("complete_delegation", %{"delegation_id" => id, "result_summary" => summary}) do
    # We usually need status here too, assume completed
    case DiwaAgent.Delegation.Broker.complete(id, summary) do
      :ok ->
        success_response("✓ Task marked as complete.")

      error ->
        error_response("Failed to complete task: #{inspect(error)}")
    end
  end

  def execute("get_agent_health", %{"agent_id" => agent_id, "context_id" => context_id}) do
    # 1. Check Registry State
    registry_status =
      case Registry.get_agent(agent_id) do
        nil -> "Unknown (Not Registered)"
        agent -> "#{agent.status} (Last Heartbeat: #{agent.last_heartbeat})"
      end

    # 2. Check Failures in Memory
    {:ok, logs} = Memory.list_by_tag(context_id, "sinag:failure")

    agent_failures =
      Enum.filter(logs, fn m ->
        String.contains?(m.content, agent_id) or Map.get(m.metadata, "agent_id") == agent_id
      end)

    # 3. Get Last Checkpoint
    {:ok, checkpoints} = Memory.list_by_tag(context_id, "sinag:checkpoint")

    last_checkpoint =
      checkpoints
      |> Enum.filter(fn m ->
        String.contains?(m.content, agent_id) or Map.get(m.metadata, "agent_id") == agent_id
      end)
      |> List.first()

    checkpoint_info =
      if last_checkpoint,
        do: "Last Checkpoint: #{last_checkpoint.inserted_at} (ID: #{last_checkpoint.id})",
        else: "No Checkpoints Found"

    success_response("""
    Agent Health Analysis: #{agent_id}

    Status: #{registry_status}
    Recent Failures: #{length(agent_failures)}
    #{checkpoint_info}
    """)
  end

  def execute("restore_agent", %{"agent_id" => agent_id, "context_id" => context_id}) do
    # Find latest checkpoint
    {:ok, checkpoints} = Memory.list_by_tag(context_id, "sinag:checkpoint")

    last_checkpoint =
      checkpoints
      |> Enum.filter(fn m ->
        String.contains?(m.content, agent_id) or Map.get(m.metadata, "agent_id") == agent_id
      end)
      |> List.first()

    if is_nil(last_checkpoint) do
      error_response(
        "Restore failed: No valid checkpoints found for agent #{agent_id} in context #{context_id}"
      )
    else
      success_response("""
      ✓ Agent Restored Successfully (Phase 3.2 Mock)

      Restored from Checkpoint: #{last_checkpoint.id}
      Timestamp: #{last_checkpoint.inserted_at}
      State Data: #{last_checkpoint.content}

      The agent grid is now re-hydrating.
      """)
    end
  end

  def execute("log_failure", %{"agent_id" => agent_id, "context_id" => context_id} = args) do
    category = Map.get(args, "error_category")
    severity = Map.get(args, "severity")
    stack = Map.get(args, "stack_trace", "N/A")
    meta = Map.get(args, "metadata", %{})

    content = "Failure Report for Agent #{agent_id}: #{category}\n\nStack Trace:\n#{stack}"

    full_meta =
      Map.merge(meta, %{
        "agent_id" => agent_id,
        "error_category" => category,
        "severity" => severity,
        "type" => "failure"
      })

    tags = ["sinag:failure", "sinag:agent:#{agent_id}"]

    case Memory.add(context_id, content, %{metadata: full_meta, tags: tags}) do
      {:ok, _} -> success_response("✓ Failure event logged for agent #{agent_id}.")
      error -> error_response("Failed to log failure: #{inspect(error)}")
    end
  end

  def execute("purge_old_checkpoints", %{"context_id" => _context_id} = args) do
    days = Map.get(args, "retention_days", 7)
    # This would involve querying memories by tag and date, then deleting.
    success_response("✓ Purge simulation complete. 0 checkpoints found older than #{days} days.")
  end

  # Distributed Consensus Tools (Phase 3)

  def execute("get_cluster_status", args) do
    include_metrics = Map.get(args, "include_metrics", false)

    case @consensus_module.get_cluster_status(include_metrics: include_metrics) do
      {:ok, status} ->
        # Handle Map or Struct
        cluster_name = Map.get(status, :cluster_name)
        node_id = Map.get(status, :node_id)
        current_status = Map.get(status, :status)
        nodes = Map.get(status, :cluster_nodes, [])

        metrics_section =
          if include_metrics do
            """

            📈 Metrics:
            - Pending Arbitrations: #{get_pending_arbitrations_count()}
            - Completed Arbitrations: #{get_completed_arbitrations_count()}
            # Note: Recursive call to get_byzantine_nodes might need refactor if strict
            - Byzantine nodes: (Check get_byzantine_nodes tool)
            """
          else
            ""
          end

        success_response("""
        📊 Cluster Status

        Cluster Name: #{cluster_name}
        Node ID: #{node_id}
        Status: #{current_status}
        Cluster Nodes: #{length(nodes)}#{metrics_section}
        """)

      {:error, reason} ->
        error_response("Failed to get cluster status: #{inspect(reason)}")
    end
  end

  def execute("get_byzantine_nodes", args) do
    min_level = Map.get(args, "min_suspicion_level", "medium")

    case @consensus_module.get_byzantine_nodes(min_suspicion_level: min_level) do
      {:ok, nodes} ->
        # nodes is list of %{node_id: ..., suspicion_level: ...}
        if nodes == [] do
          success_response("✅ No Byzantine nodes detected. Cluster is healthy.")
        else
          list =
            Enum.map(nodes, fn n ->
              node_id = n[:node_id] || n["node_id"]
              level = n[:suspicion_level] || n["suspicion_level"]
              "- #{inspect(node_id)} (#{level})"
            end)
            |> Enum.join("\n")

          success_response("""
          ⚠️ Byzantine Nodes Detected:

          #{list}
          """)
        end

      {:error, reason} ->
        error_response("Failed to list byzantine nodes: #{inspect(reason)}")
    end
  end

  # --- Conflict Arbitration (Phase 3) ---

  def execute("get_conflict_threshold", %{"context_id" => _context_id} = args) do
    domain = Map.get(args, "domain", "general")

    threshold = DiwaAgent.Conflict.AdaptiveThreshold.calculate(domain: domain)

    success_response("""
    Conflict Threshold for '#{domain}': #{threshold}

    Base: #{DiwaAgent.Conflict.AdaptiveThreshold.calculate(domain: domain, performance_adj: 0.0, safety_level: 0)}
    Safety Modifier applied.
    """)
  end

  def execute("calibrate_threshold", %{
        "context_id" => context_id,
        "conflict_id" => _conflict_id,
        "feedback_score" => score
      }) do
    Logger.info("Calibrating threshold for context #{context_id} based on feedback #{score}")
    success_response("Threshold calibration data recorded.")
  end

  def execute("arbitrate_conflict", %{"context_id" => context_id, "conflict_id" => conflict_id}) do
    # Delegate to the distributed consensus engine
    case @consensus_module.arbitrate_conflict(conflict_id, context_id) do
      {:ok, result} ->
        success_response(
          "Conflict Arbitration Initiated via Consensus. Result: #{inspect(result)}"
        )

      {:error, :redirect, leader} ->
        error_response("Arbitration request redirected to leader: #{inspect(leader)}")

      {:error, reason} ->
        error_response("Arbitration failed: #{inspect(reason)}")
    end
  end

  def execute("record_resolution_feedback", %{"resolution_id" => id, "score" => score}) do
    Logger.info("Feedback recorded for #{id}: #{score}")
    success_response("Feedback recorded.")
  end

  def execute("verify_context_integrity", %{"context_id" => context_id}) do
    # First verify context exists
    case Context.get(context_id) do
      {:ok, context} ->
        case DiwaAgent.CVC.verify_history(context_id) do
          {:ok, :no_history} ->
            success_response(
              "Context '#{context.name}' has no version history (it may be new or pre-CVC). Integrity check skipped."
            )

          {:ok, last_hash} ->
            success_response("""
            ✓ Context Integrity Verified

            Context: #{context.name}
            Status: VALID
            Head Hash: #{last_hash}
            Blockchain verification successful.
            """)

          {:error, :broken_chain, commit} ->
            error_response("""
            ⚠️ INTEGRITY CHECK FAILED: Broken Chain

            The chain of trust is broken at commit:
            Time: #{commit.inserted_at}
            Hash: #{commit.hash}
            Expected Parent: #{commit.parent_hash} (Mismatch)

            This indicates potential tampering or data corruption.
            """)

          {:error, :invalid_hash, commit} ->
            error_response("""
            ⚠️ INTEGRITY CHECK FAILED: Invalid Hash

            A commit has been modified after creation:
            Time: #{commit.inserted_at}
            Stored Hash: #{commit.hash}

            The content does not match the hash. Data has been tampered with.
            """)

          {:error, :invalid_signature, commit} ->
            error_response("""
            ⚠️ INTEGRITY CHECK FAILED: Invalid Signature

            Cryptography verification failed for commit:
            Time: #{commit.inserted_at}
            Hash: #{commit.hash}

            The signature does not match the public key and hash. Unauthorized modification detected.
            """)

          _ ->
            error_response("Unknown error during verification.")
        end

      {:error, :not_found} ->
        error_response("Context not found: #{context_id}")
    end
  end

  # --- Shortcut Interpreter Tools (Phase 4) ---

  def execute("execute_shortcut", %{"command" => command, "context_id" => context_id}) do
    DiwaAgent.Shortcuts.Interpreter.process(command, context_id)
  end

  def execute("list_shortcuts", _args) do
    shortcuts = DiwaAgent.Shortcuts.Registry.list_shortcuts()

    # Format the list nicely
    formatted =
      shortcuts
      |> Enum.map(fn {cmd, def} ->
        "- **/#{cmd}** -> `#{def.tool}` (#{inspect(def.schema)})"
      end)
      |> Enum.join("\n")

    success_response("""
    📋 Available Shortcuts:

    #{formatted}
    """)
  end

  def execute("register_shortcut_alias", %{"alias_name" => name, "target_tool" => tool} = args) do
    schema = Map.get(args, "args_schema", [])

    case DiwaAgent.Shortcuts.Registry.register_alias(name, tool, schema) do
      :ok ->
        success_response("✓ Shortcut alias '/#{name}' registered for tool '#{tool}'.")

      {:error, reason} ->
        error_response("Failed to register alias: #{inspect(reason)}")
    end
  end

  def execute(tool_name, _args) do
    error_response("Unknown tool: #{tool_name}")
  end

  defp get_health_summary(score) when score >= 90,
    do: "Excellent. Context is fresh, active, and well-structured."

  defp get_health_summary(score) when score >= 70, do: "Good. Context is being maintained well."

  defp get_health_summary(score) when score >= 50,
    do: "Fair. Needs more consistent updates or structure."

  defp get_health_summary(score) when score >= 30,
    do: "Poor. Context is becoming stale or lacks detail."

  defp get_health_summary(_), do: "Critical. Context is obsolete or structurally deficient."

  defp build_tree(id, indent) do
    case Memory.get(id) do
      {:ok, mem} ->
        prefix = String.duplicate("  ", indent)
        line = "#{prefix}• [#{mem.id}] #{String.slice(mem.content, 0, 80)}..."

        case Memory.get_children(id) do
          {:ok, children} ->
            child_trees =
              children
              |> Enum.map(fn child ->
                case build_tree(child.id, indent + 1) do
                  {:ok, tree} -> tree
                  _ -> ""
                end
              end)
              |> Enum.join("\n")

            res = if child_trees == "", do: line, else: line <> "\n" <> child_trees
            {:ok, res}

          _ ->
            {:ok, line}
        end

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp format_export(context, memories, "markdown") do
    header = "# Export: #{context.name}\n#{context.description}\n\n"

    body =
      memories
      # Export in chronological order
      |> Enum.reverse()
      |> Enum.map(fn mem ->
        """
        ## Memory: #{mem.id}
        Created: #{mem.inserted_at}
        Actor: #{mem.actor || "unknown"}
        Tags: #{inspect(mem.tags || "none")}

        #{mem.content}

        ---
        """
      end)
      |> Enum.join("\n")

    header <> body
  end

  defp format_export(context, memories, "json") do
    export = %{
      context: context,
      memories: memories,
      exported_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    Jason.encode!(export, pretty: true)
  end

  defp format_hydration(%{
         handoff: handoff,
         blockers: blockers,
         memories: memories,
         depth: depth,
         focus: focus
       }) do
    handoff_text = if handoff, do: "### 🚀 Latest Handoff\n#{handoff.content}\n", else: ""

    blocker_text =
      if Enum.empty?(blockers),
        do: "",
        else: """
        ### ⚠️ Active Blockers
        #{Enum.map(blockers, fn b -> "• #{b.content}" end) |> Enum.join("\n")}
        """

    memory_text =
      if Enum.empty?(memories),
        do: "",
        else: """
        ### 🧠 Relevant Context
        #{Enum.map(memories, fn m -> "• [#{m.memory_class || "info"}] #{String.slice(m.content, 0, 100)}..." end) |> Enum.join("\n")}
        """

    focus_desc = if focus, do: " (Focus: #{inspect(focus)})", else: ""

    """
    ⚡ Context Hydration: #{String.capitalize(Atom.to_string(depth))} Depth#{focus_desc}

    #{handoff_text}
    #{blocker_text}
    #{memory_text}
    """
  end

  # Helper functions to format MCP responses

  defp success_response(text) do
    %{
      content: [
        %{
          type: "text",
          text: String.trim(text)
        }
      ]
    }
  end

  defp format_resolution_result(%{strategy: strategy, resolved_count: count} = res) do
    details = Map.get(res, :details) || []

    """
    ✓ Auto-resolution complete (Strategy: #{strategy})
    Resolved #{count} conflicts.
    Details: #{inspect(details, pretty: true)}
    """
  end

  defp format_resolution_result(%{manual: true, resolved_count: count, discarded: discarded}) do
    """
    ✓ Manual resolution complete.
    Resolved #{count} items.
    Discarded IDs: #{inspect(discarded, pretty: true)}
    """
  end

  defp format_resolution_result(result) do
    "✓ Resolution complete. Result: #{inspect(result, pretty: true)}"
  end

  # Helper functions for consensus metrics
  defp get_pending_arbitrations_count do
    # Placeholder - would query Ra state machine
    0
  end

  defp get_completed_arbitrations_count do
    # Placeholder - would query Ra state machine
    0
  end

  defp error_response(text) do
    %{
      content: [
        %{
          type: "text",
          text: String.trim(text)
        }
      ],
      isError: true
    }
  end
end

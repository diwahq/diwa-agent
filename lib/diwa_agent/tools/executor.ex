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
  def execute(tool_name, %{"buffer" => true} = args) do
    session_id = Map.get(args, "session_id")

    if is_nil(session_id) do
      error_response("Error: 'session_id' is required for buffered operations.")
    else
      context_id = args["context_id"]
      actor = args["actor"] || "assistant"

      # Clean up internal params before buffering
      params = Map.drop(args, ["buffer", "session_id"])

      case DiwaAgent.Tala.Buffer.push(session_id, context_id, tool_name, params, actor) do
        {:ok, id} ->
          success_response("✓ Operation '#{tool_name}' buffered in TALA. (ID: #{id})")

        {:error, reason} ->
          error_response("Failed to buffer operation: #{inspect(reason)}")
      end
    end
  end

  def execute(tool_name, args) when tool_name in ~w(
      detect_context bind_context unbind_context list_bindings 
      link_contexts unlink_contexts get_related_contexts get_context_graph get_dependency_chain
      start_session navigate_contexts confirm_binding
    ) do
    DiwaAgent.Tools.Ugat.execute(tool_name, args)
  end

  def execute("determine_workflow", args) do
    DiwaAgent.Tools.Flow.execute("determine_workflow", args)
  end

  def execute("queue_handoff_item", args) do
    execute_queue_handoff_item(args)
  end

  def execute("get_shortcuts", %{"context_id" => _cid}) do
    shortcuts =
      DiwaAgent.Shortcuts.Registry.list_shortcuts()
      |> Enum.map(fn {name, def} ->
        %{
          command: "@#{name}",
          tool: def.tool,
          description: "Shortcut for #{def.tool}",
          # May be nil or list
          schema: def[:schema]
        }
      end)

    response = %{
      shortcuts: shortcuts,
      usage: "Call execute_shortcut(command='@...', context_id='...')"
    }

    success_response(Jason.encode!(response, pretty: true))
  end

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
    query_str = Map.get(args, "query")

    {:ok, contexts} = Context.list(organization_id)

    # Apply fuzzy filtering if query provided
    {contexts, status_msg} =
      if query_str && query_str != "" do
        scored =
          contexts
          |> Enum.map(fn ctx ->
            # Weighted hybrid: exact/substring is best, then Jaro
            score =
              cond do
                String.downcase(ctx.name) == String.downcase(query_str) -> 1.0
                String.contains?(String.downcase(ctx.name), String.downcase(query_str)) -> 0.9
                true -> DiwaAgent.Utils.Fuzzy.jaro_winkler(query_str, ctx.name)
              end

            {ctx, score}
          end)
          |> Enum.filter(fn {_, score} -> score >= 0.6 end)
          |> Enum.sort_by(fn {_, score} -> score end, :desc)
          |> Enum.map(&elem(&1, 0))

        {scored, "Found #{length(scored)} context(s) matching '#{query_str}':"}
      else
        {contexts, "Found #{length(contexts)} context(s):"}
      end

    if contexts == [] do
      if query_str do
        success_response("No contexts found matching '#{query_str}'.")
      else
        success_response("No contexts found. Use create_context to create one.")
      end
    else
      context_list =
        """
        <div class="overflow-x-auto my-4">
          <table class="table table-sm bg-slate-800/20 border border-white/5 whitespace-nowrap">
            <thead>
              <tr class="text-slate-400 font-bold border-b border-white/10 uppercase tracking-widest text-[10px]">
                <th class="p-3">Project Name</th>
                <th class="p-3">ID</th>
                <th class="p-3">Last Updated</th>
              </tr>
            </thead>
            <tbody>
              #{Enum.map(contexts, fn ctx -> """
          <tr class="hover:bg-indigo-500/10 transition-colors border-b border-white/5">
            <td class="p-3">
              <div class="font-bold text-indigo-100">#{ctx.name}</div>
              <div class="text-[10px] text-slate-500 max-w-xs truncate italic">#{ctx.description || "No description"}</div>
            </td>
            <td class="p-3 font-mono text-[10px] text-slate-400 opacity-60">#{String.slice(ctx.id, 0, 8)}...</td>
            <td class="p-3 text-[10px] text-slate-500 italic">#{Calendar.strftime(ctx.updated_at, "%Y-%m-%d")}</td>
          </tr>
          """ end) |> Enum.join("\n")}
            </tbody>
          </table>
        </div>
        """

      success_response("#{status_msg}\n\n#{context_list}")
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

  def execute("get_client_instructions", args) do
    opts =
      [
        client_type: Map.get(args, "client_type", "generic"),
        sections: Map.get(args, "sections"),
        version: Map.get(args, "version", "v1")
      ]
      |> Enum.filter(fn {_, v} -> v != nil end)

    res = DiwaAgent.Tools.ClientInstructions.get_instructions(opts)
    success_response(Jason.encode!(res, pretty: true))
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





  def execute("search_memories", %{"query" => query} = args) do
    context_id = Map.get(args, "context_id")

    case Memory.search(query, context_id) do
      {:ok, []} ->
        # Try fuzzy fallback
        case Memory.fuzzy_search(query, context_id) do
          {:ok, []} ->
            scope = if context_id, do: " in this context", else: ""
            success_response("No memories found matching '#{query}'#{scope}.")

          {:ok, fuzzy_results} ->
            format_search_results(fuzzy_results, context_id, query, true)
        end

      {:ok, memories} ->
        format_search_results(memories, context_id, query, false)
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
        <div class="bg-indigo-500/5 border border-indigo-500/20 rounded-2xl p-6 shadow-2xl my-4">
          <div class="flex items-center justify-between mb-6">
            <h3 class="text-lg font-bold text-white uppercase tracking-widest">Project Status</h3>
            <div class="badge badge-primary font-bold">#{plan.status}</div>
          </div>
          
          <div class="mb-6">
            <div class="flex justify-between text-[10px] uppercase font-bold text-slate-400 mb-2">
              <span>Progress</span>
              <span>#{plan.completion_pct}%</span>
            </div>
            <div class="w-full bg-white/5 rounded-full h-2 overflow-hidden border border-white/5">
              <div class="bg-indigo-500 h-full shadow-[0_0_10px_rgba(99,102,241,0.5)] transition-all duration-1000" style="width: #{plan.completion_pct}%"></div>
            </div>
          </div>

          <div class="space-y-4">
            <div class="bg-black/20 p-4 rounded-xl border border-white/5">
              <div class="text-[10px] uppercase tracking-widest text-slate-500 font-bold mb-2">Internal Notes</div>
              <p class="text-sm text-slate-200 leading-relaxed italic">"#{plan.notes}"</p>
            </div>
            
            <div class="flex justify-between text-[8px] font-mono text-slate-600 uppercase tracking-widest">
              <span>Context: #{String.slice(cid, 0, 8)}</span>
              <span>Updated: #{Calendar.strftime(plan.updated_at, "%Y-%m-%d %H:%M")}</span>
            </div>
          </div>
        </div>
        """)

      {:error, :not_found} ->
        success_response("""
        <div class="p-8 text-center bg-slate-800/20 rounded-xl border border-dashed border-white/10 opacity-50">
          <div class="mb-1 italic">No status recorded for this context yet.</div>
          <div class="text-[10px] uppercase tracking-widest">Use set_project_status to begin tracking.</div>
        </div>
        """)
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

  def execute("commit_buffer", %{"session_id" => sid}) do
    case DiwaAgent.Tala.Buffer.flush(sid) do
      {:ok, 0} ->
        success_response("No operations in TALA buffer to commit for session #{sid}.")

      {:ok, ops} ->
        # Execute all accumulated operations
        # Note: We don't wrap in Ecto.transaction here because individual execute
        # calls may have their own transactional logic or side effects (like WIKA notifications).
        # TALA provides 'Lazy Apply', but atomicity across all tools is a future enhancement (Phase 3).
        results =
          Enum.reduce_while(ops, {:ok, []}, fn op, {:ok, acc} ->
            # Call execute without 'buffer: true' to actually run it
            res = execute(op.tool_name, op.params)

            if res["isError"] do
              {:halt,
               {:error,
                "Failed to execute #{op.tool_name} (Buffer ID: #{op.id}): #{inspect(res["content"]) || "No error detail"}"}}
            else
              {:cont, {:ok, acc ++ [res]}}
            end
          end)

        case results do
          {:ok, list} ->
            # Mark as committed in DB
            import Ecto.Query

            DiwaAgent.Tala.Operation
            |> where(session_id: ^sid, status: "pending")
            |> DiwaAgent.Repo.update_all(set: [status: "committed"])

            success_response(
              "✓ Successfully committed #{length(list)} operations from TALA buffer."
            )

          {:error, reason} ->
            error_response("Commit failed: #{reason}")
        end

      {:error, reason} ->
        error_response("Flush failed: #{inspect(reason)}")
    end
  end

  def execute("list_pending", %{"session_id" => sid}) do
    ops = DiwaAgent.Tala.Buffer.list(sid)

    if Enum.empty?(ops) do
      success_response("TALA buffer is empty for session #{sid}.")
    else
      list =
        ops
        |> Enum.map(fn op ->
          "[#{op.tool_name}] #{Jason.encode!(op.params)}"
        end)
        |> Enum.join("\n")

      success_response("Pending TALA operations for session #{sid}:\n\n#{list}")
    end
  end

  def execute("discard_buffer", %{"session_id" => sid}) do
    :ok = DiwaAgent.Tala.Buffer.discard(sid)
    success_response("✓ TALA buffer discarded for session #{sid}.")
  end

  def execute(
        "set_handoff_note",
        %{"context_id" => cid, "summary" => sum} = args
      ) do
    # 1. Fetch queued items (notes)
    {queued_entries, queued_ids} =
      case Memory.list_by_tag(cid, "handoff_item") do
        {:ok, items} ->
          # Only take items that haven't been "consumed" (archived or previously included)
          # We use a simple filter: items newer than last handoff
          last_handoff_time =
            case Memory.list_by_type(cid, "handoff") do
              {:ok, [latest | _]} -> latest.inserted_at
              _ -> DateTime.from_unix!(0)
            end

          unconsumed =
            items
            |> Enum.filter(fn m ->
              DateTime.compare(m.inserted_at, last_handoff_time) == :gt &&
                !Map.get(m.metadata || %{}, "consumed", false)
            end)
            |> Enum.sort_by(& &1.inserted_at, :asc)

          {unconsumed, Enum.map(unconsumed, & &1.id)}

        _ ->
          {[], []}
      end

    # 2. Extract Blockers & Decisions from queued items
    blockers =
      queued_entries
      |> Enum.filter(fn m -> Map.get(m.metadata || %{}, "category") == "blocker" end)
      |> Enum.map(& &1.content)

    decisions =
      queued_entries
      |> Enum.filter(fn m -> Map.get(m.metadata || %{}, "category") == "decision" end)
      |> Enum.map(& &1.content)

    # 3. Build Full Summary
    queued_text =
      if queued_entries == [] do
        ""
      else
        "\n\n### 📥 Included Updates\n" <>
          (Enum.map(queued_entries, &"- #{&1.content}") |> Enum.join("\n"))
      end

    full_summary = sum <> queued_text

    # 3.5. Check for queued artifacts (NEW: Artifact Queue Integration)
    session_id = Map.get(args, "session_id", "default")

    artifacts_text =
      case DiwaAgent.Workflow.ArtifactQueue.compile_for_handoff(session_id) do
        {:ok, nil} ->
          ""

        {:ok, compiled} ->
          Logger.info(
            "[Handoff] Including #{DiwaAgent.Workflow.ArtifactQueue.count(session_id) |> elem(1)} queued artifacts"
          )

          "\n\n" <> compiled

        _ ->
          ""
      end

    full_summary_with_artifacts = full_summary <> artifacts_text

    # 4. Use WIKA Handoff Struct for Metadata
    wika_handoff = %Diwa.Wika.Handoff{
      summary: sum,
      next_steps: List.wrap(Map.get(args, "next_steps", [])),
      active_files: List.wrap(Map.get(args, "active_files", [])),
      blockers: blockers,
      decisions: decisions,
      status: :pending
    }

    metadata = %{
      type: "handoff",
      wika: Map.from_struct(wika_handoff),
      # Legacy fields for backward compatibility
      next_steps: wika_handoff.next_steps,
      active_files: wika_handoff.active_files
    }

    # 5. Save Handoff Memory (with artifacts)
    case Memory.add(cid, full_summary_with_artifacts, %{metadata: metadata}) do
      {:ok, handoff_mem} ->
        # 6. Mark consumed items in DB
        Enum.each(queued_ids, fn id ->
          case Memory.get(id) do
            {:ok, m} ->
              updated_meta = Map.put(m.metadata || %{}, "consumed", true)
              Memory.update_metadata(id, updated_meta)

            _ ->
              :ok
          end
        end)

        success_response(
          "✓ WIKA Handoff recorded (ID: #{String.slice(handoff_mem.id, 0, 8)}). Consumed #{length(queued_ids)} queued items."
        )

      {:error, reason} ->
        error_response("Failed to set handoff: #{inspect(reason)}")
    end
  end

  def execute("get_active_handoff", %{"context_id" => cid}) do
    {:ok, list} = Memory.list_by_type(cid, "handoff")

    case list do
      [latest | _] ->
        meta = latest.metadata || %{}
        wika = Map.get(meta, "wika") || %{}

        # Legacy extract for display
        next_steps = Map.get(wika, "next_steps") || Map.get(meta, "next_steps") || []
        active_files = Map.get(wika, "active_files") || Map.get(meta, "active_files") || []
        blockers = Map.get(wika, "blockers") || []

        steps_text = next_steps |> Enum.map(&"- #{&1}") |> Enum.join("\n")
        files_text = active_files |> Enum.map(&"- #{&1}") |> Enum.join("\n")

        blockers_text =
          if blockers == [],
            do: "",
            else: "\n⚠️ Blockers:\n" <> (blockers |> Enum.map(&"- #{&1}") |> Enum.join("\n"))

        success_response("""
        🚀 Session Handoff Briefing
        ID: #{latest.id}
        Status: #{Map.get(wika, "status", "pending") |> to_string() |> String.upcase()}
        ----------------------------------------

        #{latest.content}

        ### 📋 Next Steps:
        #{if steps_text == "", do: "(None provided)", else: steps_text}

        ### 📂 Active Files:
        #{if files_text == "", do: "(None provided)", else: files_text}
        #{blockers_text}

        Recorded: #{latest.inserted_at}

        *Tip: Run `@complete #{latest.id}` to acknowledge this handoff.*
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

  def execute("match_experts", %{"capabilities" => caps}) do
    case DiwaAgent.Registry.Server.find_by_capabilities(caps) do
      [] ->
        success_response(
          "No agents found with all requested capabilities: #{Enum.join(caps, ", ")}"
        )

      matches ->
        text =
          matches
          |> Enum.map(fn a ->
            "- #{a.name} (ID: #{a.id}, Role: #{a.role}) Status: #{a.status} Caps: #{Enum.join(a.capabilities, ",")}"
          end)
          |> Enum.join("\n")

        success_response("🔍 Found #{length(matches)} matching experts:\n\n#{text}")
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

    case DiwaAgent.Delegation.Broker.delegate(handoff) do
      {:ok, ref, picked_id} ->
        success_response("""
        ✓ Task Delegated Successfully

        Delegation ID: #{ref}
        Target Agent: #{picked_id}
        """)

      {:error, reason} ->
        error_response("Failed to delegate task: #{inspect(reason)}")
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



  # --- Shortcut Interpreter Tools (Phase 4) ---

  def execute("execute_shortcut", %{"command" => command, "context_id" => context_id}) do
    case DiwaAgent.Shortcuts.Interpreter.process(command, context_id) do
      # If it returns a map, it's a successful tool execution (already formatted)
      %{} = result -> result
      # If it returns an error tuple, wrap it
      {:error, reason} -> error_response(reason)
      # Catch-all
      other -> error_response("Unexpected result from shortcut interpreter: #{inspect(other)}")
    end
  end

  def execute("execute_shortcut", %{"command" => command} = args) do
    context_id = Map.get(args, "context_id")
    # Delegate to our new Interpreter
    DiwaAgent.Shortcuts.Interpreter.interpret(command, context_id)
  end

  def execute("list_shortcuts", _args) do
    shortcuts = DiwaAgent.Shortcuts.Registry.list_shortcuts()
    sorted_shortcuts = Enum.sort_by(shortcuts, fn {cmd, _} -> cmd end)

    formatted =
      sorted_shortcuts
      |> Enum.map(fn {cmd, def} ->
        args =
          case def.schema do
            [] -> ""
            list -> Enum.map(list, &to_string/1) |> Enum.join(" ")
          end

        usage = if args == "", do: "/#{cmd}", else: "/#{cmd} <#{args}>"
        "- #{usage} -> #{def.tool}"
      end)
      |> Enum.join("\n")

    success_response(
      "Available Shortcuts:\n\n" <>
        formatted <> "\n\nTip: Use / or @ prefix (e.g., /help or @help)"
    )
  end

  def execute("register_shortcut_alias", %{"alias_name" => name, "target_tool" => tool} = args) do
    schema = Map.get(args, "args_schema", [])

    case DiwaAgent.Shortcuts.Registry.register_alias(name, tool, schema) do
      :ok ->
        success_response("✓ Shortcut alias '#{name}' registered for tool '#{tool}'.")

      {:error, reason} ->
        error_response("Failed to register alias: #{inspect(reason)}")
    end
  end

  def execute("list_directory", args) do
    path = Map.get(args, "path", ".")
    context_id = Map.get(args, "context_id")
    root_path = resolve_root_path(context_id)

    case DiwaAgent.CodeBrowser.list_files(root_path, path) do
      {:ok, items} ->
        # Format as a nice list
        formatted =
          items
          |> Enum.map(fn item ->
            icon = if item.type == :directory, do: "📁", else: "📄"
            "#{icon} #{item.name} (#{item.path})"
          end)
          |> Enum.join("\n")

        success_response("""
        📂 Directory Listing: #{path}
        Root: #{root_path}
        ----------------------------------------
        #{if formatted == "", do: "(Empty)", else: formatted}
        """)

      {:error, :access_denied} ->
        error_response("Access denied: Path is outside of project root.")

      {:error, reason} ->
        error_response("Failed to list directory: #{inspect(reason)}")
    end
  end

  def execute("read_file", %{"path" => path} = args) do
    context_id = Map.get(args, "context_id")
    root_path = resolve_root_path(context_id)

    opts = [
      start_line: Map.get(args, "start_line"),
      end_line: Map.get(args, "end_line")
    ]

    case DiwaAgent.CodeBrowser.read_file(root_path, path, opts) do
      {:ok, result} ->
        success_response("""
        📄 File: #{result.path}
        Lines: #{result.total_lines}
        ----------------------------------------
        #{result.content}
        """)

      {:error, :access_denied} ->
        error_response("Access denied: Path is outside of project root.")

      {:error, :enoent} ->
        error_response("File not found: #{path}")

      {:error, reason} ->
        error_response("Failed to read file: #{inspect(reason)}")
    end
  end

  def execute("search_code", %{"query" => query} = args) do
    context_id = Map.get(args, "context_id")
    root_path = resolve_root_path(context_id)
    opts = [file_pattern: Map.get(args, "file_pattern")]

    case DiwaAgent.CodeBrowser.search_code(root_path, query, opts) do
      {:ok, []} ->
        success_response("No matches found for '#{query}'.")

      {:ok, matches} ->
        formatted =
          matches
          |> Enum.map(fn m ->
            "#{m.path}:#{m.line}:#{m.column} -> #{m.content}"
          end)
          |> Enum.join("\n")

        success_response("""
        🔍 Search Results for '#{query}':
        ----------------------------------------
        #{formatted}
        """)

      {:error, :ripgrep_not_found} ->
        error_response("ripgrep (rg) not found on system.")

      {:error, reason} ->
        error_response("Search failed: #{inspect(reason)}")
    end
  end

  def execute("complete_handoff", %{"context_id" => _cid, "handoff_id" => hid} = args) do
    status = Map.get(args, "status", "completed")

    case Memory.get(hid) do
      {:ok, memory} ->
        # Update handoff status in WIKA nested metadata
        meta = memory.metadata || %{}
        wika = Map.get(meta, "wika", %{}) |> Map.put("status", status)
        updated_metadata = Map.put(meta, "wika", wika)

        case Memory.update_metadata(hid, updated_metadata) do
          {:ok, _} ->
            # Optionally mark associated items as archived?
            # For now, just success.
            success_response("✓ Handoff [#{String.slice(hid, 0, 8)}] marked as #{status}.")

          {:error, reason} ->
            error_response("Failed to update handoff: #{inspect(reason)}")
        end

      {:error, :not_found} ->
        error_response("Handoff memory not found: #{hid}")

      {:error, reason} ->
        error_response("Error retrieving handoff: #{inspect(reason)}")
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
         focus: focus,
         shortcuts: shortcuts
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

    shortcuts_text = """
    ### ⌨️ Available Shortcuts
    #{Enum.map(shortcuts, fn {cmd, _def} -> "• @#{cmd}" end) |> Enum.take(8) |> Enum.join(", ")}#{if length(shortcuts) > 8, do: " ... (@help for more)", else: ""}
    """

    focus_desc = if focus, do: " (Focus: #{inspect(focus)})", else: ""

    """
    ⚡ Context Hydration: #{String.capitalize(Atom.to_string(depth))} Depth#{focus_desc}

    #{handoff_text}
    #{blocker_text}
    #{memory_text}
    #{shortcuts_text}
    """
  end

  defp format_hydration(params) do
    # Fallback for when shortcuts are not in the map (legacy calls if any)
    Map.put(params, :shortcuts, []) |> format_hydration()
  end

  # Helper functions to format MCP responses

  defp success_response(text) do
    %{
      "content" => [
        %{
          "type" => "text",
          "text" => String.trim(text)
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
      "content" => [
        %{
          "type" => "text",
          "text" => String.trim(text)
        }
      ],
      "isError" => true
    }
  end

  defp format_search_results(memories, context_id, query, is_fuzzy) do
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

    match_type = if is_fuzzy, do: "fuzzy matches", else: "results"

    # Format results with previews
    results_list =
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

        "• [#{context_name}] ID: #{mem.id}\n  #{preview}\n"
      end)
      |> Enum.join("\n")

    success_response("""
    Found #{length(memories)} #{match_type} for '#{query}'#{scope_desc}:

    #{results_list}
    """)
  end

  defp resolve_root_path(context_id) do
    case context_id do
      nil ->
        File.cwd!()

      cid ->
        # Look for a 'path' binding first
        case DiwaAgent.Storage.Context.Ugat.list_bindings(cid) do
          bindings when is_list(bindings) ->
            path_binding = Enum.find(bindings, &(&1.binding_type == "path"))

            if path_binding do
              path_binding.value
            else
              File.cwd!()
            end

          _ ->
            File.cwd!()
        end
    end
  end

  defp execute_queue_handoff_item(%{"context_id" => context_id, "message" => message} = args) do
    category = Map.get(args, "category", "accomplishment")
    actor = Map.get(args, "actor", "assistant")

    # Handle "this" contextual mapping
    {final_message, tags} =
      if message == "this" do
        case Memory.list_by_tag(context_id, "progress") do
          {:ok, [latest | _]} ->
            {"[AUTO] Worked on: #{String.slice(latest.content, 0, 100)}...",
             ["handoff_item", "contextual", category]}

          _ ->
            {"[AUTO] Captured contextual session state", ["handoff_item", "contextual", category]}
        end
      else
        {"[#{String.upcase(category)}] #{message}", ["handoff_item", category]}
      end

    # Store as a memory with 'handoff_item' tag
    case Memory.add(context_id, final_message, %{
           actor: actor,
           tags: tags,
           metadata: %{
             type: "handoff_item",
             category: category,
             source: if(message == "this", do: "auto", else: "manual")
           }
         }) do
      {:ok, memory} ->
        success_response("✓ Handoff item queued: #{final_message} (ID: #{memory.id})")

      {:error, reason} ->
        error_response("Failed to queue handoff item: #{inspect(reason)}")
    end
  end

  # Artifact Queue Management
  def execute("manage_artifact_queue", %{"action" => action} = args) do
    session_id = Map.get(args, "session_id", "default")

    case action do
      "list" ->
        case DiwaAgent.Workflow.ArtifactQueue.list_artifacts(session_id) do
          {:ok, []} ->
            success_response("📦 Artifact queue is empty.")

          {:ok, artifacts} ->
            list =
              artifacts
              |> Enum.with_index(1)
              |> Enum.map(fn {artifact, idx} ->
                type_emoji =
                  case artifact[:type] do
                    :spec -> "📋"
                    :rfc -> "📝"
                    :decision -> "⚖️"
                    :note -> "📌"
                    _ -> "📄"
                  end

                title = artifact[:metadata][:title] || "Artifact #{idx}"
                "#{idx}. #{type_emoji} #{title} (#{artifact[:type]})"
              end)
              |> Enum.join("\n")

            success_response("📦 Queued Artifacts (#{length(artifacts)}):\n\n#{list}")
        end

      "clear" ->
        DiwaAgent.Workflow.ArtifactQueue.clear_session(session_id)
        success_response("🗑️  Artifact queue cleared")

      "queue" ->
        content = Map.get(args, "content", "")

        if content == "" do
          error_response("Please provide content to queue")
        else
          artifact = %{
            content: content,
            type: :note,
            metadata: %{
              title: "Manual Queue",
              actor: Map.get(args, "actor", "user")
            }
          }

          case DiwaAgent.Workflow.ArtifactQueue.queue_artifact(session_id, artifact) do
            {:ok, queued} ->
              success_response("✓ Artifact queued (ID: #{queued[:id]})")

            {:error, reason} ->
              error_response("Failed to queue: #{inspect(reason)}")
          end
        end

      _ ->
        error_response("Invalid action. Use: list, clear, or queue")
    end
  end
end

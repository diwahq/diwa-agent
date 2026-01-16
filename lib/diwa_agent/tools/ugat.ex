defmodule DiwaAgent.Tools.Ugat do
  @moduledoc """
  Tool execution logic for Project UGAT (Context Intelligence).
  Splitting this out from Executor to keep it clean.
  """

  alias DiwaAgent.Storage.Context.Ugat
  alias DiwaAgent.Storage.Context
  require Logger

  def execute("detect_context", %{"type" => type, "value" => value}) do
    case Ugat.detect_context(type, value) do
      %DiwaSchema.Core.ContextBinding{context: context} ->
        success_response("""
        ✓ Context Detected!
        Name: #{context.name}
        ID: #{context.id}
        Matched Binding: #{type} = #{value}
        """)

      nil ->
        error_response("No context found matching #{type} = '#{value}'")
    end
  end

  def execute("bind_context", %{"context_id" => cid, "type" => type, "value" => value} = args) do
    # Verify context exists first
    case Context.get(cid) do
      {:ok, _} ->
        metadata_str = Map.get(args, "metadata", "{}")
        metadata = decode_metadata(metadata_str)

        case Ugat.add_binding(cid, type, value, metadata) do
          {:ok, binding} ->
            success_response("""
            ✓ Context Bound Successfully
            ID: #{binding.id}
            Binding: #{type} -> #{value}
            """)

          {:error, changeset} ->
            error_response("Binding failed: #{inspect(changeset.errors)}")
        end

      {:error, :not_found} ->
        error_response("Context not found: #{cid}")
    end
  end

  def execute("unbind_context", %{"binding_id" => bid}) do
    case Ugat.remove_binding(bid) do
      {:ok, _} -> success_response("✓ Binding removed.")
      {:error, :not_found} -> error_response("Binding not found.")
    end
  end

  def execute("list_bindings", %{"context_id" => cid}) do
    bindings = Ugat.list_bindings(cid)

    if bindings == [] do
      success_response("No bindings found for this context.")
    else
      list =
        Enum.map(bindings, fn b ->
          "• [#{b.binding_type}] #{b.value} (ID: #{b.id})"
        end)
        |> Enum.join("\n")

      success_response("Bindings for context #{cid}:\n\n#{list}")
    end
  end

  def execute(
        "link_contexts",
        %{"source_context_id" => src, "target_context_id" => tgt, "relationship_type" => type} =
          args
      ) do
    # Verify both contexts
    with {:ok, _} <- Context.get(src),
         {:ok, _} <- Context.get(tgt) do
      metadata_str = Map.get(args, "metadata", "{}")
      metadata = decode_metadata(metadata_str)

      case Ugat.link_contexts(src, tgt, type, metadata) do
        {:ok, link} ->
          success_response("""
          ✓ Contexts Linked
          #{src} --[#{type}]--> #{tgt}
          ID: #{link.id}
          """)

        {:error, :circular_dependency_detected} ->
          error_response("Failed: Circular dependency detected in 'depends_on' chain.")

        {:error, :self_reference} ->
          error_response("Failed: Cannot link a context to itself.")

        {:error, changeset} ->
          error_response("Linking failed: #{inspect(changeset.errors)}")
      end
    else
      _ -> error_response("One or both contexts not found.")
    end
  end

  def execute("unlink_contexts", %{"relationship_id" => rid}) do
    case Ugat.unlink_contexts(rid) do
      {:ok, _} -> success_response("✓ Link removed.")
      {:error, :not_found} -> error_response("Link not found.")
    end
  end

  def execute("get_related_contexts", %{"context_id" => cid} = args) do
    direction_str = Map.get(args, "direction", "outgoing")

    direction =
      try do
        String.to_existing_atom(direction_str)
      rescue
        _ -> :outgoing
      end

    links = Ugat.get_relationships(cid, direction)

    if links == [] do
      success_response("No related contexts found (#{direction}).")
    else
      list =
        Enum.map(links, fn r ->
          target_name =
            if Ecto.assoc_loaded?(r.target_context),
              do: r.target_context.name,
              else: "ID: #{r.target_context_id}"

          source_name =
            if Ecto.assoc_loaded?(r.source_context),
              do: r.source_context.name,
              else: "ID: #{r.source_context_id}"

          rel_str =
            case direction do
              :outgoing ->
                "-> #{target_name} [#{r.relationship_type}]"

              :incoming ->
                "<- #{source_name} [#{r.relationship_type}]"

              :both ->
                if r.source_context_id == cid do
                  "-> #{target_name} [#{r.relationship_type}]"
                else
                  "<- #{source_name} [#{r.relationship_type}]"
                end
            end

          "• #{rel_str} (Link ID: #{r.id})"
        end)
        |> Enum.join("\n")

      success_response("Related Contexts (#{direction}):\n\n#{list}")
    end
  end

  def execute("get_context_graph", %{"root_id" => root_id} = args) do
    depth = Map.get(args, "depth", 3)
    format_str = Map.get(args, "format", "mermaid")

    opts = [depth: depth, format: format_str]

    case Ugat.get_context_graph(root_id, opts) do
      {:ok, result} ->
        formatted =
          if is_binary(result) do
            result
          else
            Jason.encode!(result, pretty: true)
          end

        success_response(formatted)

      {:error, reason} ->
        error_response("Graph traversal failed: #{inspect(reason)}")
    end
  end

  def execute("get_dependency_chain", %{"context_id" => cid}) do
    case Ugat.get_dependency_chain(cid) do
      {:ok, chain} ->
        if chain == [] do
          success_response("No dependencies found for context #{cid}.")
        else
          # Format as numbered list 1..N
          list =
            chain
            |> Enum.with_index(1)
            |> Enum.map(fn {ctx, idx} ->
              "#{idx}. #{ctx.name} (ID: #{ctx.id})"
            end)
            |> Enum.join("\n")

          success_response("""
          📋 Dependency Chain (Build Order):

          #{list}
          """)
        end

      {:error, :cycle_detected} ->
        error_response("Failed: Cycle detected in dependencies.")

      {:error, reason} ->
        error_response("Failed to retrieve chain: #{inspect(reason)}")
    end
  end

  def execute("analyze_impact", %{"context_id" => cid}) do
    impacted = Ugat.analyze_impact(cid)

    if impacted == [] do
      success_response("✓ No downstream impacts detected. No other contexts depend on this one.")
    else
      list = Enum.map(impacted, &"• #{&1.name} (#{&1.id})") |> Enum.join("\n")

      success_response("""
      ⚠️  CASCADE IMPACT ANALYSIS (Downstream Dependents)
      --------------------------------------------------
      Changing this context will affect the following projects:

      #{list}
      """)
    end
  end

  def execute("find_shortest_path", %{"source_context_id" => src, "target_context_id" => tgt}) do
    case Ugat.find_shortest_path(src, tgt) do
      {:ok, path} ->
        chain =
          path
          |> Enum.map(& &1.name)
          |> Enum.join(" → ")

        success_response("""
        🔍 Relationship Chain Found:
        #{chain}

        Steps: #{length(path) - 1}
        """)

      {:error, :no_path_found} ->
        error_response("No relationship path found between these contexts.")
    end
  end

  def execute("navigate_contexts", args) do
    cid = Map.get(args, "context_id")
    target_path = Map.get(args, "target_path", ".")
    mode = Map.get(args, "mode", "list")

    cond do
      is_nil(cid) or cid == "" ->
        error_response("context_id is required for navigate_contexts.")

      true ->
        case Ugat.navigate(cid, target_path, mode) do
          {:ok, result} ->
            header = """
            📍 Graph Navigator
            PWD: #{result.context_name} (#{result.new_context_id})
            Mode: #{result.mode}
            ----------------------------------------
            """

            body =
              case result.mode do
                "list" ->
                  if result.data == [] do
                    """
                    <div class="p-8 text-center bg-slate-800/20 rounded-xl border border-dashed border-white/10 opacity-50">
                      <div class="mb-1 italic">No related contexts found</div>
                    </div>
                    """
                  else
                    items =
                      Enum.map(result.data, fn n ->
                        dir_icon =
                          if n.direction == :outgoing,
                            do: "hero-arrow-up-right",
                            else: "hero-arrow-down-left"

                        dir_color =
                          if n.direction == :outgoing,
                            do: "text-emerald-400",
                            else: "text-amber-400"

                        rel_badge =
                          case n.relationship do
                            "depends_on" -> "badge-error"
                            "child_of" -> "badge-info"
                            "blocks" -> "badge-warning"
                            _ -> "badge-ghost"
                          end

                        """
                        <div class="group flex items-center justify-between p-3 rounded-xl hover:bg-white/5 border border-transparent hover:border-white/5 transition-all">
                          <div class="flex items-center gap-3">
                            <div class="p-2 rounded-lg bg-slate-900/50">
                              <span class="hero-icon #{dir_icon} size-4 #{dir_color}"></span>
                            </div>
                            <div>
                              <div class="font-bold text-slate-100 italic">#{n.name}</div>
                              <div class="text-[10px] uppercase tracking-tighter opacity-40">#{n.id}</div>
                            </div>
                          </div>
                          <div class="badge #{rel_badge} badge-outline badge-xs opacity-80 uppercase font-bold text-[8px] tracking-widest">
                            #{n.relationship}
                          </div>
                        </div>
                        """
                      end)
                      |> Enum.join("\n")

                    """
                    <div class="space-y-1 my-3">
                      #{items}
                    </div>
                    """
                  end

                "tree" ->
                  relationships = result.data.relationships || []

                  if relationships != [] do
                    """
                    <div class="mermaid bg-black/40 p-4 rounded-xl border border-white/5 my-4">
                      graph LR
                      #{Enum.join(relationships, "\n                ")}
                    </div>
                    """
                  else
                    "<div class='opacity-50 italic'>No relationships to graph</div>"
                  end

                "detail" ->
                  d = result.data

                  """
                  <div class="bg-indigo-500/5 border border-indigo-500/20 rounded-2xl p-6 shadow-2xl relative overflow-hidden group my-4">
                    <div class="absolute top-0 right-0 p-4 opacity-10 group-hover:opacity-30 transition-opacity">
                      <span class="hero-square-3-stack-3d size-16"></span>
                    </div>
                    
                    <div class="relative z-10">
                      <h3 class="text-xl font-bold text-white mb-1">#{d.name}</h3>
                      <p class="text-slate-400 text-sm mb-6 leading-relaxed italic">#{d.description || "No description provided."}</p>
                      
                      <div class="grid grid-cols-2 gap-4">
                        <div class="bg-black/20 p-3 rounded-xl border border-white/5 transition-transform hover:scale-105">
                          <div class="text-[10px] uppercase tracking-widest text-indigo-400 font-bold mb-1">Memories</div>
                          <div class="text-2xl font-mono text-white">#{d.memory_count}</div>
                        </div>
                        <div class="bg-black/20 p-3 rounded-xl border border-white/5 transition-transform hover:scale-105">
                          <div class="text-[10px] uppercase tracking-widest text-emerald-400 font-bold mb-1">Created</div>
                          <div class="text-xs text-slate-300 font-mono">#{Calendar.strftime(d.inserted_at, "%Y-%m-%d")}</div>
                        </div>
                      </div>

                      <div class="mt-6 flex flex-wrap gap-2">
                        #{if d.bindings == [], do: "<span class='text-[10px] italic opacity-40 italic'>No bindings</span>", else: Enum.map(d.bindings, fn b -> "<span class='px-2 py-1 rounded-md bg-white/5 border border-white/10 text-[9px] font-mono text-slate-400'>#{b}</span>" end) |> Enum.join("")}
                      </div>
                    </div>
                  </div>
                  """

                _ ->
                  "Unknown mode"
              end

            success_response(header <> body)

          {:error, :no_parent_found} ->
            error_response("Cannot go up '..': No parent context found.")

          {:error, :path_not_found} ->
            error_response("Path not found: '#{target_path}'")

          {:error, reason} ->
            error_response("Navigation failed: #{inspect(reason)}")
        end
    end
  end

  alias DiwaAgent.Storage.{Memory, Task}

  def execute("start_session", args) do
    try do
      # 1. Try smart selection first if no explicit context_id
      smart_result =
        if Map.has_key?(args, "context_id") do
          {:delegate, :standard_flow}
        else
          DiwaAgent.Workflow.Session.start_with_smart_selection(args)
        end

      case smart_result do
        {:delegate, :standard_flow} ->
          # Use explicit context_id or proceed with standard detection
          execute_standard_start_session(args)

        {:auto_select, context_id, context_name} ->
          # Auto-selected single context
          Logger.info("[Session] Auto-selected: #{context_name}")
          auto_msg = DiwaAgent.Workflow.Session.format_auto_select_message(context_name)

          # Start session with auto-selected context
          args_with_context = Map.put(args, "context_id", context_id)
          execute_standard_start_session(args_with_context, auto_msg)

        {:recent_sessions, recent, all_contexts} ->
          # Offer recent session resume
          prompt = DiwaAgent.Workflow.Session.format_recent_sessions_prompt(recent, all_contexts)
          success_response(prompt)

        {:select_context, contexts} ->
          # Show context list for selection
          prompt = DiwaAgent.Workflow.Session.format_context_list_prompt(contexts)
          success_response(prompt)

        {:error, :no_contexts, _message} ->
          # Fallback to standard flow (which will trigger onboarding/creation)
          execute_standard_start_session(args)

        {:error, _reason, message} ->
          error_response("Session start failed: #{message}")

        _ ->
          # Fallback to standard flow
          execute_standard_start_session(args)
      end
    rescue
      e ->
        Logger.error("CRASH in start_session: #{inspect(e)}")
        error_response("Internal Server Error during start_session: #{Exception.message(e)}")
    end
  end

  defp execute_standard_start_session(args, prefix_message \\ nil) do
    # 1. Resolve Context ID
    context_id = resolve_context_id(args)

    if context_id do
      # 2. Start Session
      actor = Map.get(args, "actor", "user")
      depth = Map.get(args, "depth", "standard")

      case DiwaAgent.ContextBridge.LiveSync.start_session(context_id, actor, %{}) do
        {:ok, session} ->
          # 3. Retrieve additional info based on depth
          # 3. Retrieve additional info based on depth

          # Fetch Handoff
          handoff_data =
            case Memory.list_by_type(context_id, "handoff") do
              {:ok, [latest | _]} ->
                meta =
                  if is_binary(latest.metadata) do
                    case Jason.decode(latest.metadata) do
                      {:ok, m} -> m
                      _ -> %{}
                    end
                  else
                    latest.metadata
                  end

                %{
                  summary: latest.content,
                  next_steps: meta["next_steps"] || [],
                  active_files: meta["active_files"] || [],
                  date: latest.inserted_at
                }

              _ ->
                nil
            end

          # Fetch pending tasks (standard/comprehensive only)
          pending_tasks =
            if depth in ["standard", "comprehensive"] do
              case Task.get_pending(context_id, 5) do
                {:ok, tasks} ->
                  Enum.map(tasks, fn t ->
                    %{id: t.id, title: t.title, priority: t.priority, description: t.description}
                  end)

                _ ->
                  []
              end
            else
              []
            end

          # Fetch shortcuts
          shortcuts =
            DiwaAgent.Shortcuts.Registry.list_shortcuts()
            |> Enum.map(fn {name, def} ->
              %{
                command: "@#{name}",
                tool: def.tool,
                description: "Shortcut for #{def.tool}"
              }
            end)
            |> Enum.sort_by(& &1.command)

          # Fetch client instructions (Dynamic Prompting)
          client_type = Map.get(args, "client_type", "generic")

          instructions =
            DiwaAgent.Tools.ClientInstructions.get_instructions(client_type: client_type)

          # Construct Response
          response = %{
            message: "✓ Session started for context #{context_id}",
            session_id: session.id,
            context: %{id: context_id, depth: depth},
            handoff: handoff_data,
            pending_tasks: pending_tasks,
            shortcuts: %{
              enabled: true,
              prefix: "@",
              available: shortcuts,
              instructions: instructions.instructions,
              checksum: instructions.checksum
            }
          }

          success_response(Jason.encode!(response))

        {:error, reason} ->
          error_response("Failed to start session: #{inspect(reason)}")
      end
    else
      # --- Onboarding Logic (Spec ea554e89) ---
      path = Map.get(args, "path")
      git_remote = Map.get(args, "git_remote")

      {:ok, suggestions} = Ugat.suggest_contexts(path: path, git_remote: git_remote)

      onboarding_resp = %{
        status: "not_found",
        detection: %{
          path: path,
          git_remote: git_remote,
          methods_tried: ["git_remote", "path"]
        },
        onboarding: %{
          suggestions: suggestions,
          options: [
            %{key: "session_only", label: "Start session-only"},
            %{key: "create_new", label: "Create new context"}
          ],
          prompt: "Reply with a number (1-5) or context name to bind, or use 'session_only'."
        }
      }

      # We return as success but with status: not_found so the agent can handle it gracefully
      success_response(Jason.encode!(onboarding_resp))
    end
  end

  def execute("confirm_binding", args) do
    action = Map.get(args, "action")
    binding_type = Map.get(args, "binding_type", "git_remote")
    actor = Map.get(args, "actor", "user")

    # 1. Resolve Binding Value (Auto-detect if missing)
    binding_value =
      Map.get(args, "binding_value") ||
        if binding_type == "git_remote", do: detect_git_remote(), else: Map.get(args, "path")

    if is_nil(binding_value) do
      error_response(
        "Could not determine binding value (path/remote). Please provide explicitly."
      )
    else
      # 2. Resolve Context ID
      context_id_arg = Map.get(args, "context_id")
      context_name = Map.get(args, "context_name")

      context_id =
        cond do
          context_id_arg ->
            context_id_arg

          context_name ->
            case DiwaAgent.Storage.Context.find_by_name(context_name) do
              {:ok, ctx} -> ctx.id
              _ -> nil
            end

          true ->
            nil
        end

      case {action, context_id} do
        {"bind", nil} ->
          error_response("Please provide a valid context_id or context_name to bind.")

        {"bind", cid} ->
          case Ugat.add_binding(cid, binding_type, binding_value) do
            {:ok, _} ->
              execute("start_session", %{"actor" => actor, binding_type => binding_value})

            {:error, reason} ->
              error_response("Failed to bind context: #{inspect(reason)}")
          end

        {"session_only", cid} ->
          execute("start_session", %{"context_id" => cid, "actor" => actor})

        {"create_new", _} ->
          name = Map.get(args, "context_name", "New Project")

          case DiwaAgent.Storage.Context.create(name, "Generated via onboarding") do
            {:ok, context} ->
              Ugat.add_binding(context.id, binding_type, binding_value)
              execute("start_session", %{"context_id" => context.id, "actor" => actor})

            {:error, reason} ->
              error_response("Failed to create context: #{inspect(reason)}")
          end

        _ ->
          error_response("Invalid action or missing context: #{action}")
      end
    end
  end

  defp resolve_context_id(args) do
    # Priority:
    # 1. Explicit context_id
    # 2. Path binding
    # 3. Git Remote binding

    cond do
      Map.has_key?(args, "context_id") ->
        Map.get(args, "context_id")

      path = Map.get(args, "path") ->
        # Try path detection
        case Ugat.detect_context("path", path) do
          %DiwaSchema.Core.ContextBinding{context: context} ->
            context.id

          nil ->
            # If path fails, try git remote if provided
            git_remote = Map.get(args, "git_remote")

            if git_remote do
              case Ugat.detect_context("git_remote", git_remote) do
                %DiwaSchema.Core.ContextBinding{context: context} -> context.id
                _ -> nil
              end
            else
              nil
            end
        end

      git_remote = Map.get(args, "git_remote") ->
        case Ugat.detect_context("git_remote", git_remote) do
          %DiwaSchema.Core.ContextBinding{context: context} -> context.id
          _ -> nil
        end

      true ->
        nil
    end
  end

  # Helpers

  defp success_response(text) do
    %{
      "content" => [%{"type" => "text", "text" => text}],
      "isError" => false
    }
  end

  defp error_response(text) do
    %{
      "content" => [%{"type" => "text", "text" => text}],
      "isError" => true
    }
  end

  defp decode_metadata(str) do
    case Jason.decode(str) do
      {:ok, val} -> val
      _ -> %{}
    end
  end

  defp detect_git_remote do
    case System.cmd("git", ["remote", "get-url", "origin"], stderr_to_stdout: true) do
      {url, 0} -> String.trim(url)
      _ -> nil
    end
  end
end

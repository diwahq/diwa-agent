defmodule DiwaAgent.Tools.Flow do
  @moduledoc """
  Logic for `@flow` shortcut and `determine_workflow` tool.
  Implements strict priority-based workflow detection and role-aware routing.
  """

  alias DiwaAgent.Storage.Memory
  require Logger

  # --- Public Tool API ---

  def execute("determine_workflow", args) do
    query = Map.get(args, "query")
    context_id = Map.get(args, "context_id")

    # 1. Detect Role & Analyze State
    role = detect_role(context_id)
    state = analyze_state(context_id)

    # 2. Determine Workflow (The Core Logic)
    result = determine_best_workflow(context_id, role, state, query)

    # 3. Format Response
    success_response(format_flow_response(role, result, state))
  end

  # --- Core Logic: Priority Determination ---

  defp determine_best_workflow(context_id, role, state, query) do
    # This pipeline tries to match workflows in P0 -> P1 -> P2 -> P3 order

    find_start_workflow(context_id) ||
      find_p0_workflow(role, state) ||
      find_p1_workflow(role, state, query) ||
      find_p2_workflow(role, state) ||
      find_p3_workflow(role, state) ||
      fallback_workflow(role)
  end

  defp find_start_workflow(nil) do
    %{
      type: :start_fresh,
      priority: :p3,
      reason: "No active context found. Start a new session.",
      cmd: "@start",
      desc: "Initialize session"
    }
  end

  defp find_start_workflow(_), do: nil

  # P0: Immediate / Critical
  defp find_p0_workflow(_role, %{has_blockers: true} = _state) do
    %{
      type: :resolve_blocker,
      priority: :p0,
      reason: "Critical blockers detected. Resolution is mandatory.",
      cmd: "@resolve_blocker",
      desc: "Address active blockers"
    }
  end

  defp find_p0_workflow(_role, %{has_conflicts: true} = _state) do
    %{
      type: :resolve_conflict,
      priority: :p0,
      reason: "Knowledge conflicts detected. Arbitration required.",
      cmd: "@resolve_conflict",
      desc: "Resolve state conflicts"
    }
  end

  defp find_p0_workflow(:coder, %{test_failures: failures} = _state) when failures > 0 do
    %{
      type: :fix_failing_tests,
      priority: :p0,
      reason: "#{failures} tests are failing.",
      cmd: "@test",
      desc: "Fix failing tests"
    }
  end

  defp find_p0_workflow(_, _), do: nil

  # P1: High Priority
  defp find_p1_workflow(:coder, %{pending_handoff: true}, _query) do
    %{
      type: :process_handoff,
      priority: :p1,
      reason: "New handoff received from Planner.",
      cmd: "@resume",
      desc: "Process incoming handoff"
    }
  end

  defp find_p1_workflow(:coder, %{recent_files: files}, _query) when length(files) > 0 do
    %{
      type: :continue_implementation,
      priority: :p1,
      reason: "Resume work on recently edited files.",
      cmd: "@ls",
      desc: "Continue implementation"
    }
  end

  defp find_p1_workflow(:planner, %{pending_tasks: count}, _query) when count > 0 do
    %{
      type: :continue_planning,
      priority: :p1,
      reason: "#{count} high-priority tasks pending.",
      cmd: "@todo",
      desc: "Prioritize pending tasks"
    }
  end

  defp find_p1_workflow(_role, _state, query) when is_binary(query) and query != "" do
    %{
      type: :custom_query,
      priority: :p1,
      reason: "User specified intent: '#{query}'",
      cmd: "@chat",
      desc: "Execute custom query"
    }
  end

  defp find_p1_workflow(_, _, _), do: nil

  # P2: Normal
  defp find_p2_workflow(:planner, _) do
    %{
      type: :spec_review,
      priority: :p2,
      reason: "Review and refine existing specifications.",
      cmd: "@stat",
      desc: "Review spec status"
    }
  end

  defp find_p2_workflow(:coder, _) do
    %{
      type: :improve_health,
      priority: :p2,
      reason: "Refactor and improve codebase health.",
      cmd: "@stat",
      desc: "Check context health"
    }
  end

  # P3: Low / Start Fresh
  defp find_p3_workflow(_, _) do
    %{
      type: :start_fresh,
      priority: :p3,
      reason: "No active context found. Start a new session.",
      cmd: "@start",
      desc: "Initialize session"
    }
  end

  defp fallback_workflow(_) do
    %{
      type: :unknown,
      priority: :p3,
      reason: "Standard workflow",
      cmd: "@help",
      desc: "View commands"
    }
  end

  # --- Analysis & Detection ---

  defp analyze_state(nil), do: default_state()

  defp analyze_state(context_id) do
    # In a real implementation we would fetch these from the DB/Tools
    # mocking basic checks based on memory tags for now

    {:ok, recent} = Memory.list(context_id, limit: 30)

    %{
      has_blockers: tags_exist?(recent, "blocker"),
      has_conflicts: tags_exist?(recent, "conflict"),
      test_failures: count_by_tag(recent, "test_failure"),
      pending_handoff: tags_exist?(recent, "handoff_to_coder"),
      pending_tasks: count_by_tag(recent, "requirement"),
      recent_files: extract_recent_files(recent)
    }
  end

  defp default_state do
    %{
      has_blockers: false,
      has_conflicts: false,
      test_failures: 0,
      pending_handoff: false,
      pending_tasks: 0,
      recent_files: []
    }
  end

  defp tags_exist?(memories, tag) do
    Enum.any?(memories, fn m -> m.tags && tag in m.tags end)
  end

  defp count_by_tag(memories, tag) do
    Enum.count(memories, fn m -> m.tags && tag in m.tags end)
  end

  defp extract_recent_files(memories) do
    memories
    |> Enum.flat_map(fn m ->
      case m.metadata do
        %{"active_files" => files} when is_list(files) -> files
        _ -> []
      end
    end)
    |> Enum.uniq()
    |> Enum.take(3)
  end

  # --- Role Detection ---

  defp detect_role(context_id) do
    # 1. Context/Memory Override (Explicit Mode)
    # 2. Fallback to Session Actor (Implicit Mode)
    detect_role_from_context(context_id) || detect_role_from_actor() || :coder
  end

  defp detect_role_from_context(context_id) do
    if context_id do
      case Memory.list(context_id, limit: 10) do
        {:ok, memories} ->
          raw_role =
            Enum.find_value(memories, fn m ->
              case Regex.run(~r/actor[^\w]*\s+(\w+)/i, m.content) do
                [_, role] -> String.downcase(role)
                _ -> nil
              end
            end)

          normalize_role(raw_role)

        _ ->
          nil
      end
    end
  end

  defp normalize_role("claude"), do: :planner
  defp normalize_role("human"), do: :planner
  defp normalize_role("antigravity"), do: :coder
  defp normalize_role("gemini"), do: :coder
  defp normalize_role("cursor"), do: :coder
  defp normalize_role(_), do: nil

  defp detect_role_from_actor do
    raw = get_current_actor()
    normalize_role(String.downcase(raw))
  end

  defp get_current_actor do
    # This would ideally come from the tool args or session context
    # defaulting to antigravity for this agent
    "antigravity"
  end

  # --- Formatting ---

  defp format_flow_response(role, result, state) do
    role_str = String.capitalize(to_string(role))
    prio_str = String.upcase(to_string(result.priority))

    icon =
      case result.priority do
        :p0 -> "🚨"
        :p1 -> "⚡"
        :p2 -> "🌊"
        _ -> "🌱"
      end

    files_note =
      if state.recent_files != [] do
        files = Enum.join(state.recent_files, ", ")
        "\n   Context: #{length(state.recent_files)} active files (#{files})"
      else
        ""
      end

    """
    #{icon} **DIWA FLOW**: #{role_str} Mode (#{prio_str})

    **Recommended Action**: `#{result.type}`
    > #{result.reason}

    👉 **Run**: `#{result.cmd}`
    #{files_note}

    *Alternates:*
    • #{result.desc}
    """
  end

  defp success_response(text) do
    %{
      "content" => [
        %{"type" => "text", "text" => String.trim(text)}
      ]
    }
  end
end

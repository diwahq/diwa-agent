defmodule DiwaAgent.ContextBridge.Hydration do
  @moduledoc """
  Module 5: ContextHydration
  Handles intelligent context retrieval within token budgets and focus areas.
  """

  alias DiwaAgent.Storage.Memory
  require Logger

  @doc """
  Hydrates a context briefing based on depth and focus.
  """
  def hydrate(context_id, opts \\ []) do
    # :minimal, :standard, :comprehensive
    depth = opts[:depth] || :standard
    # list of keywords or tags
    focus = opts[:focus]
    # dummy limit for now
    _token_limit = opts[:token_limit] || 4000

    # 1. Always get the latest handoff
    handoff = get_latest_handoff(context_id)

    # 2. Get active blockers
    blockers = get_active_blockers(context_id)

    # 3. Get domain-specific context based on focus and depth
    relevant_memories = get_relevant_context(context_id, focus, depth)

    # 4. Get available shortcuts
    shortcuts = DiwaAgent.Shortcuts.Registry.list_shortcuts()

    {:ok, %{
      handoff: handoff,
      blockers: blockers,
      memories: relevant_memories,
      shortcuts: shortcuts,
      depth: depth,
      focus: focus
    }}
  end

  defp get_latest_handoff(context_id) do
    case Memory.list_by_type(context_id, "handoff") do
      {:ok, [latest | _]} -> latest
      _ -> nil
    end
  end

  defp get_active_blockers(context_id) do
    # Filter for active blockers in metadata
    case Memory.list_by_type(context_id, "blocker") do
      {:ok, blockers} ->
        Enum.filter(blockers, fn b ->
          meta = if is_binary(b.metadata), do: Jason.decode!(b.metadata), else: b.metadata
          meta["status"] == "active"
        end)

      _ ->
        []
    end
  end

  defp get_relevant_context(context_id, focus, depth) do
    limit =
      case depth do
        :minimal -> 5
        :standard -> 15
        :comprehensive -> 40
      end

    if focus && length(focus) > 0 do
      # Search focused keywords
      query = Enum.join(focus, " ")

      case Memory.search(query, context_id) do
        {:ok, memories} -> Enum.take(memories, limit)
        _ -> []
      end
    else
      # Just get latest important memories
      case Memory.list(context_id, limit: limit) do
        {:ok, memories} -> memories
        _ -> []
      end
    end
  end
end

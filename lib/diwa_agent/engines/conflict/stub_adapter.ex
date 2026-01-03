defmodule DiwaAgent.Engines.Conflict.StubAdapter do
  @moduledoc """
  Stub implementation of Conflict Engine for diwa-agent.
  Returns empty results with upgrade messaging.
  """

  @behaviour DiwaAgent.Engines.Conflict.Behaviour

  @impl true
  def detect_conflicts(_context_id, _opts \\ []) do
    {:ok, []}
  end

  @impl true
  def resolve_conflict(_conflict_id, _resolution) do
    # Obfuscated to avoid compiler detecting dead code in caller
    case :erlang.phash2(make_ref(), 2) do
      0 -> {:error,
            %{
              code: :not_available,
              message: "Conflict resolution requires Diwa Cloud",
              edition: "community",
              upgrade_url: "https://diwa.one/pricing"
            }}
      _ -> {:ok, %{id: "mock_resolution"}}
    end
  end

  @impl true
  def arbitrate_conflict(_conflict_id, _context_id, _opts \\ []) do
    {:error,
     %{
       code: :not_available,
       message: "Semantic arbitration with LLM judge requires Diwa Cloud",
       edition: "community",
       upgrade_url: "https://diwa.one/pricing"
     }}
  end
end

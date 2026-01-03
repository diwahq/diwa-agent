defmodule DiwaAgent.Engines.Health.StubAdapter do
  @moduledoc """
  Stub implementation of Health Engine for diwa-agent.
  Returns placeholder values with upgrade messaging.
  """

  @behaviour DiwaAgent.Engines.Health.Behaviour

  @impl true
  def calculate_health(_context_id) do
    {:ok,
     %{
       score: 50,
       grade: "C",
       breakdown: %{
         completeness: 50,
         freshness: 50,
         coherence: 50,
         coverage: 50
       },
       recommendations: [
         "Upgrade to Diwa Cloud for detailed health scoring",
         "Visit https://diwa.one/pricing for more information"
       ],
       calculated_at: DateTime.utc_now(),
       edition: "community",
       upgrade_url: "https://diwa.one/pricing"
     }}
  end

  @impl true
  def get_health_breakdown(_context_id) do
    {:ok,
     %{
       components: [],
       message: "Detailed health breakdown requires Diwa Cloud",
       edition: "community",
       upgrade_url: "https://diwa.one/pricing",
       calculated_at: DateTime.utc_now()
     }}
  end
end

defmodule DiwaAgent.Engines.Cluster.StubAdapter do
  @moduledoc """
  Stub for distributed cluster features.
  Returns standalone mode status.
  """

  def get_status(_opts \\ []) do
    {:ok,
     %{
       status: "standalone",
       mode: "single_node",
       nodes: [],
       leader: nil,
       edition: "community",
       message: "Distributed clustering requires Diwa Cloud",
       upgrade_url: "https://diwa.one/pricing"
     }}
  end

  def get_byzantine_nodes(_opts \\ []) do
    {:ok, []}
  end
end

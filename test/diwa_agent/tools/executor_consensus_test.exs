defmodule DiwaAgent.Tools.ExecutorConsensusTest do
  use ExUnit.Case, async: false
  alias DiwaAgent.Tools.Executor
  import Mox

  setup :verify_on_exit!
  
  setup do
    # Ensure process is started for test
    if Process.whereis(DiwaAgent.Consensus.ByzantineDetector) do
      DiwaAgent.Consensus.ByzantineDetector.reset_state()
    else
      start_supervised!(DiwaAgent.Consensus.ByzantineDetector)
    end
    :ok
  end

  describe "Consensus Tools" do
    test "get_cluster_status returns valid status" do
      DiwaAgent.Consensus.ClusterMock
      |> expect(:get_cluster_status, fn _opts ->
        {:ok, %{
          cluster_name: :diwa_agent_consensus,
          node_id: :nonode@nohost,
          members: [:nonode@nohost],
          leader_id: :nonode@nohost,
          status: :running
        }}
      end)

      result = Executor.execute("get_cluster_status", %{})
      
      assert %{content: [%{type: "text", text: text}]} = result
      assert text =~ "Cluster Status"
      assert text =~ "Cluster Name: diwa_agent_consensus"
    end

    test "get_byzantine_nodes returns list (empty initially)" do
      DiwaAgent.Consensus.ClusterMock
      |> expect(:get_byzantine_nodes, fn _opts ->
        {:ok, []}
      end)

      result = Executor.execute("get_byzantine_nodes", %{})
      
      assert %{content: [%{type: "text", text: text}]} = result
      assert text =~ "No Byzantine nodes detected"
    end
    
    test "arbitrate_conflict submits request successfully" do
      args = %{
        "context_id" => UUID.uuid4(),
        "conflict_id" => UUID.uuid4()
      }
      
      DiwaAgent.Consensus.ClusterMock
      |> expect(:arbitrate_conflict, fn _conflict_id, _context_id ->
        {:ok, "success"}
      end)
      
      result = Executor.execute("arbitrate_conflict", args)
      assert %{content: [%{type: "text", text: text}]} = result
      assert text =~ "Conflict Arbitration Initiated via Consensus"
    end
  end
end

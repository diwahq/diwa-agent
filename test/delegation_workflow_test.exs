defmodule DiwaAgent.DelegationWorkflowTest do
  use ExUnit.Case, async: false

  alias DiwaAgent.Delegation.{Broker, Worker, Handoff}
  alias DiwaAgent.Registry

  @moduletag :integration

  setup do
    # Ensure broker is started
    start_supervised!(Broker)
    start_supervised!(Registry.Server)
    start_supervised!(Worker)

    # Register a test agent
    agent = %{
      id: "test-agent-#{:rand.uniform(10000)}",
      role: :coder,
      capabilities: ["code", "test"],
      status: :idle
    }

    Registry.Server.register(agent)

    on_exit(fn ->
      Registry.Server.unregister(agent.id)
    end)

    {:ok, agent: agent}
  end

  describe "delegation workflow" do
    test "can delegate task to specific agent", %{agent: agent} do
      # Create a handoff
      handoff = %Handoff{
        type: "handoff",
        delegation_type: :agent,
        from_agent_id: "orchestrator",
        to_agent_id: agent.id,
        status: :pending,
        task_definition: "Implement user authentication feature",
        constraints: %{
          "time_limit" => "2h",
          "context_id" => "ctx-123"
        },
        timeout_at: DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_iso8601()
      }

      # Delegate the task
      {:ok, ref, target_id} = Broker.delegate(handoff)

      assert target_id == agent.id
      assert is_binary(ref)
    end

    test "can poll for delegated tasks", %{agent: agent} do
      # Create and delegate a handoff
      handoff = %Handoff{
        type: "handoff",
        delegation_type: :agent,
        from_agent_id: "orchestrator",
        to_agent_id: agent.id,
        status: :pending,
        task_definition: "Write unit tests for authentication module",
        constraints: %{"context_id" => "ctx-456"}
      }

      {:ok, _ref, _target_id} = Broker.delegate(handoff)

      # Poll for tasks
      {:ok, tasks} = Broker.poll(agent.id)

      assert length(tasks) == 1
      assert List.first(tasks).task_definition == "Write unit tests for authentication module"
    end

    test "can complete delegated task", %{agent: agent} do
      # Create and delegate a handoff
      handoff = %Handoff{
        type: "handoff",
        delegation_type: :agent,
        from_agent_id: "orchestrator",
        to_agent_id: agent.id,
        status: :pending,
        task_definition: "Refactor database query module"
      }

      {:ok, ref, _} = Broker.delegate(handoff)

      # Poll and get the task
      {:ok, [task]} = Broker.poll(agent.id)

      # Extract ref from active_files (hack from Phase 1)
      task_ref = List.first(task.active_files)

      # Complete the task
      :ok = Broker.complete(task_ref, "Refactoring completed successfully", :completed)

      # Verify no more tasks for this agent
      {:ok, remaining_tasks} = Broker.poll(agent.id)
      assert remaining_tasks == []
    end

    test "worker automatically polls and executes tasks", %{agent: agent} do
      # Create and delegate a handoff
      handoff = %Handoff{
        type: "handoff",
        delegation_type: :agent,
        from_agent_id: "orchestrator",
        to_agent_id: agent.id,
        status: :pending,
        task_definition: "Auto-executed task via worker"
      }

      {:ok, _ref, _} = Broker.delegate(handoff)

      # Trigger immediate poll
      Worker.poll_now()

      # Give worker time to process
      Process.sleep(100)

      # Verify task was processed (no more pending tasks)
      {:ok, remaining_tasks} = Broker.poll(agent.id)
      assert remaining_tasks == []
    end

    test "handles task with no matching agent gracefully" do
      # Create handoff without specifying agent
      handoff = %Handoff{
        type: "handoff",
        delegation_type: :agent,
        from_agent_id: "orchestrator",
        to_agent_id: nil,  # No specific agent
        status: :pending,
        task_definition: "Generic task",
        constraints: %{
          "required_capabilities" => ["non-existent-capability"]
        }
      }

      # Should fail to delegate
      result = Broker.delegate(handoff)
      assert {:error, :no_matching_agent_available} = result
    end
  end

  describe "handoff queue integration" do
    test "transmitted handoffs can be received" do
      # This test would require Memory storage to be set up
      # Skipping for now as it requires database context
      :ok
    end
  end
end

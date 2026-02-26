defmodule DiwaAgent.Delegation.BrokerTest do
  use ExUnit.Case, async: false

  alias DiwaAgent.Delegation.{Broker, Handoff}

  setup do
    # Broker is started by application, no need to start it here
    :ok
  end

  describe "basic delegation operations" do
    test "can delegate task to specific agent" do
      handoff = %Handoff{
        type: "handoff",
        delegation_type: :agent,
        from_agent_id: "orchestrator",
        to_agent_id: "test-agent-1",
        status: :pending,
        task_definition: "Test task"
      }

      {:ok, ref, target_id} = Broker.delegate(handoff)

      assert target_id == "test-agent-1"
      assert is_binary(ref)
    end

    test "can poll for delegated tasks" do
      handoff = %Handoff{
        type: "handoff",
        delegation_type: :agent,
        from_agent_id: "orchestrator",
        to_agent_id: "test-agent-2",
        status: :pending,
        task_definition: "Test task for polling"
      }

      {:ok, _ref, _} = Broker.delegate(handoff)

      {:ok, tasks} = Broker.poll("test-agent-2")

      assert length(tasks) == 1
      assert List.first(tasks).task_definition == "Test task for polling"
    end

    test "polling removes task from queue" do
      handoff = %Handoff{
        type: "handoff",
        delegation_type: :agent,
        from_agent_id: "orchestrator",
        to_agent_id: "test-agent-3",
        status: :pending,
        task_definition: "Test task"
      }

      {:ok, _ref, _} = Broker.delegate(handoff)

      # First poll returns the task
      {:ok, [_task]} = Broker.poll("test-agent-3")

      # Second poll returns empty
      {:ok, []} = Broker.poll("test-agent-3")
    end

    test "can complete delegated task" do
      handoff = %Handoff{
        type: "handoff",
        delegation_type: :agent,
        from_agent_id: "orchestrator",
        to_agent_id: "test-agent-4",
        status: :pending,
        task_definition: "Test task to complete"
      }

      {:ok, ref, _} = Broker.delegate(handoff)

      # Complete the task
      :ok = Broker.complete(ref, "Task completed", :completed)

      # No assertion needed - just verify it doesn't crash
      assert true
    end

    test "returns empty list when polling non-existent agent" do
      {:ok, []} = Broker.poll("non-existent-agent")
    end
  end
end

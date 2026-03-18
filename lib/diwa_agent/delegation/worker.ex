defmodule DiwaAgent.Delegation.Worker do
  @moduledoc """
  Worker GenServer for Phase 4 Auto-Execute Delegated Tasks.

  Polls the Delegation.Broker for pending tasks assigned to registered agents
  and automatically executes them.

  Features:
  - Automatic polling interval (configurable, default: 5 seconds)
  - Executes delegated tasks from DIWA queue
  - Reports task completion back to broker
  - Handles errors gracefully
  """
  use GenServer
  require Logger
  alias DiwaAgent.Delegation.{Broker, Handoff}
  alias DiwaAgent.Registry

  # Poll every 5 seconds
  @poll_interval_ms 5_000

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Trigger an immediate poll (for testing/debugging)
  """
  def poll_now do
    GenServer.cast(__MODULE__, :poll_now)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("[DiwaAgent.Delegation.Worker] Starting delegation worker")

    # Schedule first poll
    schedule_poll()

    {:ok, %{last_poll: nil, tasks_executed: 0}}
  end

  @impl true
  def handle_info(:poll, state) do
    # Poll for all registered agents
    new_state = poll_and_execute(state)

    # Schedule next poll
    schedule_poll()

    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:poll_now, state) do
    new_state = poll_and_execute(state)
    {:noreply, new_state}
  end

  # Private Helpers

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval_ms)
  end

  defp poll_and_execute(state) do
    # Get all registered agents
    agents = Registry.Server.list_agents()

    # Poll for each agent
    executed_count =
      agents
      |> Enum.map(&poll_agent/1)
      |> Enum.sum()

    %{
      state
      | last_poll: DateTime.utc_now(),
        tasks_executed: state.tasks_executed + executed_count
    }
  end

  defp poll_agent(agent) do
    case Broker.poll(agent.id) do
      {:ok, []} ->
        # No tasks for this agent
        0

      {:ok, tasks} ->
        # Execute each task
        tasks
        |> Enum.map(&execute_task(agent, &1))
        |> Enum.count(&(&1 == :ok))

      {:error, reason} ->
        Logger.error("[Delegation.Worker] Failed to poll agent #{agent.id}: #{inspect(reason)}")
        0
    end
  end

  defp execute_task(agent, %Handoff{} = handoff) do
    # Extract the handoff ID from active_files (see broker.ex line 97)
    # This is a hack from Phase 1 implementation
    handoff_id = List.first(handoff.active_files || [])

    if is_nil(handoff_id) do
      Logger.error("[Delegation.Worker] Handoff missing ID in active_files")
      :error
    else
      Logger.info("[Delegation.Worker] Executing task #{handoff_id} for agent #{agent.id}")
      Logger.debug("Task definition: #{handoff.task_definition}")

      # Execute the task based on agent role
      # Note: execute_task_by_role currently always returns {:ok, _}
      # Future implementations may return {:error, _}
      result = execute_task_by_role(agent, handoff)

      # Report completion to broker
      case result do
        {:ok, summary} ->
          Broker.complete(handoff_id, summary, :completed)
          Logger.info("[Delegation.Worker] Task #{handoff_id} completed successfully")
          :ok

        {:error, reason} ->
          Broker.complete(handoff_id, "Error: #{inspect(reason)}", :failed)
          Logger.error("[Delegation.Worker] Task #{handoff_id} failed: #{inspect(reason)}")
          :error

        other ->
          # Fallback for unexpected return values
          Broker.complete(handoff_id, "Unexpected result: #{inspect(other)}", :failed)

          Logger.error(
            "[Delegation.Worker] Task #{handoff_id} returned unexpected result: #{inspect(other)}"
          )

          :error
      end
    end
  end

  @spec execute_task_by_role(Registry.Server.agent(), Handoff.t()) ::
          {:ok, String.t()} | {:error, any()}
  defp execute_task_by_role(agent, handoff) do
    # For now, we'll implement a simple execution strategy
    # based on the agent's role

    case agent.role do
      :coder ->
        execute_coder_task(handoff)

      :planner ->
        execute_planner_task(handoff)

      :reviewer ->
        execute_reviewer_task(handoff)

      _ ->
        execute_generic_task(handoff)
    end
  end

  defp execute_coder_task(handoff) do
    # For coder tasks, we expect:
    # - task_definition contains instructions
    # - constraints may contain file paths, context_id, etc.

    task_def = handoff.task_definition
    _constraints = handoff.constraints || %{}

    # Example: Log the task (placeholder for actual implementation)
    Logger.info("[Coder Agent] Task: #{task_def}")

    # TODO: Integrate with actual agent execution system
    # This would typically call DiwaAgent.Tools.Executor or similar

    {:ok, "Coder task executed: #{String.slice(task_def, 0, 50)}..."}
  end

  defp execute_planner_task(handoff) do
    task_def = handoff.task_definition

    Logger.info("[Planner Agent] Task: #{task_def}")

    # TODO: Integrate with planning system

    {:ok, "Planner task executed: #{String.slice(task_def, 0, 50)}..."}
  end

  defp execute_reviewer_task(handoff) do
    task_def = handoff.task_definition

    Logger.info("[Reviewer Agent] Task: #{task_def}")

    # TODO: Integrate with review system

    {:ok, "Reviewer task executed: #{String.slice(task_def, 0, 50)}..."}
  end

  defp execute_generic_task(handoff) do
    task_def = handoff.task_definition

    Logger.info("[Generic Agent] Task: #{task_def}")

    # For testing typing, occasionally return error if task is "fail"
    if task_def == "fail" do
      {:error, "Generic task failure requested"}
    else
      {:ok, "Generic task executed: #{String.slice(task_def, 0, 50)}..."}
    end
  end
end

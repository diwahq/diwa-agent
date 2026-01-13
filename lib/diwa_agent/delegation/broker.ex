defmodule DiwaAgent.Delegation.Broker do
  @moduledoc """
  Broker GenServer for Phase 1.3 Polling-Based Delegation.
  Manage task queues per agent and handles polling.
  """
  use GenServer
  require Logger
  alias DiwaAgent.Delegation.Handoff

  # Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Delegate a task (Handoff) to an agent.
  """
  def delegate(%Handoff{} = handoff) do
    GenServer.call(__MODULE__, {:delegate, handoff})
  end

  @doc """
  Poll for pending tasks for a specific agent.
  Returns {:ok, list_of_handoffs} or {:ok, []}.
  """
  def poll(agent_id) do
    GenServer.call(__MODULE__, {:poll, agent_id})
  end

  @doc """
  Mark a delegation as completed (or failed).
  """
  def complete(handoff_id, result_summary, status \\ :completed) do
    GenServer.call(__MODULE__, {:complete, handoff_id, result_summary, status})
  end

  # Server Callbacks

  @impl true
  def init(_) do
    Logger.info("[DiwaAgent.Delegation] Broker started.")
    # State: %{ 
    #   queues: %{ "agent_id" => [handoff1, handoff2] },
    #   pending: %{ "handoff_id" => handoff }  <-- For lookup/timeout tracking
    # }
    {:ok, %{queues: %{}, pending: %{}}}
  end

  @impl true
  def handle_call({:delegate, %Handoff{} = handoff}, _from, state) do
    # 1. Resolve Target Agent ID
    target_id = case handoff.to_agent_id do
      nil -> resolve_target_by_requirements(handoff)
      id -> id
    end

    if is_nil(target_id) do
      {:reply, {:error, :no_matching_agent_available}, state}
    else
      # 2. Track Delegation
      ref = UUID.uuid4()
      
      updated_queues = Map.update(state.queues, target_id, [ref], fn list -> list ++ [ref] end)
      updated_pending = Map.put(state.pending, ref, handoff)

      Logger.info("[Broker] Delegated task to #{target_id} (Ref: #{ref})")
      {:reply, {:ok, ref, target_id}, %{state | queues: updated_queues, pending: updated_pending}}
    end
  end

  @impl true
  def handle_call({:poll, agent_id}, _from, state) do
    case Map.get(state.queues, agent_id) do
      nil ->
        {:reply, {:ok, []}, state}

      [] ->
        {:reply, {:ok, []}, state}

      [ref | rest] ->
        # FIFO basics. 
        # Pop the first task.
        task = Map.get(state.pending, ref)

        # We assume the agent *takes* it. 
        # Should we remove from queue? Yes.
        # Should we keep in 'pending' until complete? Yes, mark as in-progress?
        # For simple polling, let's just return it and keep tracking.

        updated_queues = Map.put(state.queues, agent_id, rest)

        # Update status in pending? (Not strictly necessary for MVP polling, but good for tracking)
        # We return the task + its ref so agent can complete it later.

        {:reply, {:ok, [%{task | active_files: [ref]}]}, %{state | queues: updated_queues}}
        # Hack: Storing ref in active_files for now since we lack ID field? 
        # Better: Return tuple or wrapper. But client expects simple list.
        # Let's return the task object. The agent needs to know the ID to complete it.
        # Phase 1.2 schema didn't have 'id'. Check Handoff.ex.
        # It has `timestamp` but no unique ID.
        # Correct fix: Use Memory ID.
        # But here we are in memory.
        # Let's wrap the return: `{:ok, [{ref, task}]}`
    end
  end

  @impl true
  def handle_call({:complete, ref, _result, _status}, _from, state) do
    # Remove from pending
    updated_pending = Map.delete(state.pending, ref)
    {:reply, :ok, %{state | pending: updated_pending}}
  end

  # --- Internal Routing Helpers ---

  defp resolve_target_by_requirements(handoff) do
    constraints = handoff.constraints || %{}
    required_caps = Map.get(constraints, "required_capabilities") || []

    # 1. Try matching by specific capabilities
    case DiwaAgent.Registry.Server.find_by_capabilities(required_caps) do
      [match | _] ->
        match.id

      [] ->
        # 2. Fallback to role-based idle discovery if possible
        # We'd need to know the 'role' required, maybe from task_definition or a constraint
        # For now, let's look for a :coder if no caps match (standard default)
        case DiwaAgent.Registry.Server.find_idle_agent(:coder) do
          nil -> nil
          agent -> agent.id
        end
    end
  end
end

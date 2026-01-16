defmodule DiwaAgent.Registry.Server do
  @moduledoc """
  GenServer that acts as the Source of Truth for all active agents.
  Handles registration, heartbeats, and status updates.
  """
  use GenServer
  require Logger
  alias DiwaAgent.Registry.Agent

  # Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Registers a new agent or updates an existing one if ID is provided.
  """
  def register(attrs) do
    GenServer.call(__MODULE__, {:register, attrs})
  end

  @doc """
  Updates the heartbeat timestamp for an agent.
  """
  def heartbeat(agent_id) do
    GenServer.cast(__MODULE__, {:heartbeat, agent_id})
  end

  @doc """
  Updates an agent's status (e.g., :busy, :idle) and current context context.
  """
  def update_status(agent_id, status, context_id \\ nil) do
    GenServer.call(__MODULE__, {:update_status, agent_id, status, context_id})
  end

  @doc """
  List all registered agents.
  """
  def list_agents do
    GenServer.call(__MODULE__, :list_agents)
  end

  @doc """
  Find an idle agent with a specific role.
  """
  def find_idle_agent(role) do
    GenServer.call(__MODULE__, {:find_idle, role})
  end

  @doc """
  Get an agent by ID.
  """
  def get_agent(agent_id) do
    GenServer.call(__MODULE__, {:get_agent, agent_id})
  end

  @doc """
  Find agents that possess all required capabilities.
  """
  def find_by_capabilities(required_caps) do
    GenServer.call(__MODULE__, {:find_by_caps, List.wrap(required_caps)})
  end

  # Server Callbacks

  @impl true
  def init(_) do
    Logger.info("[DiwaAgent.Registry] Agent Registry started.")
    # State is a map of agent_id => Agent struct
    {:ok, %{}}
  end

  @impl true
  def handle_call({:register, attrs}, _from, state) do
    agent = Agent.new(attrs)
    new_state = Map.put(state, agent.id, agent)
    Logger.info("[DiwaAgent.Registry] Agent registered: #{agent.name} (#{agent.role})")
    {:reply, {:ok, agent}, new_state}
  end

  @impl true
  def handle_call({:update_status, agent_id, status, context_id}, _from, state) do
    case Map.get(state, agent_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      agent ->
        updated_agent = %{
          agent
          | status: status,
            current_context_id: context_id,
            last_heartbeat: DateTime.utc_now()
        }

        new_state = Map.put(state, agent_id, updated_agent)
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:list_agents, _from, state) do
    agents = Map.values(state)
    {:reply, agents, state}
  end

  @impl true
  def handle_call({:find_idle, role}, _from, state) do
    match =
      state
      |> Map.values()
      |> Enum.find(fn agent ->
        agent.role == role and agent.status == :idle
      end)

    {:reply, match, state}
  end

  @impl true
  def handle_call({:get_agent, agent_id}, _from, state) do
    {:reply, Map.get(state, agent_id), state}
  end

  @impl true
  def handle_call({:find_by_caps, required}, _from, state) do
    required_set = MapSet.new(required)

    matches =
      state
      |> Map.values()
      |> Enum.filter(fn agent ->
        agent_caps = MapSet.new(agent.capabilities || [])
        MapSet.subset?(required_set, agent_caps)
      end)

    {:reply, matches, state}
  end

  @impl true
  def handle_cast({:heartbeat, agent_id}, state) do
    new_state =
      case Map.get(state, agent_id) do
        nil ->
          Logger.warning(
            "[DiwaAgent.Registry] Received heartbeat from unknown agent: #{agent_id}"
          )

          state

        agent ->
          updated = %{agent | last_heartbeat: DateTime.utc_now()}
          Map.put(state, agent_id, updated)
      end

    {:noreply, new_state}
  end
end

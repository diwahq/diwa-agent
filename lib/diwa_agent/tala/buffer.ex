defmodule DiwaAgent.Tala.Buffer do
  @moduledoc """
  Transactional Accumulation & Lazy Apply (TALA) Buffer.
  Manages deferred operation commits for AI agents.
  """
  use GenServer
  require Logger
  alias DiwaAgent.Repo

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Add an operation to the buffer for a specific session.
  """
  def push(session_id, context_id, tool_name, params, actor \\ "assistant") do
    GenServer.call(__MODULE__, {:push, session_id, context_id, tool_name, params, actor})
  end

  @doc """
  Retrieve all pending operations for a session.
  """
  def list(session_id) do
    GenServer.call(__MODULE__, {:list, session_id})
  end

  @doc """
  Discard all pending operations for a session.
  """
  def discard(session_id) do
    GenServer.call(__MODULE__, {:discard, session_id})
  end

  @doc """
  Flush the buffer and execute all operations.
  Note: Execution logic will be handled by the Tool Executor.
  """
  def flush(session_id) do
    GenServer.call(__MODULE__, {:flush, session_id})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("[TALA] Server-side buffer initialized")
    {:ok, %{buffers: %{}}}
  end

  @impl true
  def handle_call({:push, session_id, context_id, tool_name, params, actor}, _from, state) do
    op = %{
      session_id: session_id,
      context_id: context_id,
      tool_name: tool_name,
      params: params,
      actor: actor
    }

    # 1. Persist to DB for crash resilience
    case persist_operation(op) do
      {:ok, db_op} ->
        # 2. Update in-memory state
        new_buffer = Map.get(state.buffers, session_id, []) ++ [db_op]
        new_state = put_in(state.buffers[session_id], new_buffer)
        {:reply, {:ok, db_op.id}, new_state}

      {:error, reason} ->
        Logger.error("[TALA] Failed to persist operation: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:list, session_id}, _from, state) do
    # Try to load from memory first, fallback to DB if memory empty (e.g. after restart)
    buffer = Map.get(state.buffers, session_id)

    buffer =
      if is_nil(buffer) do
        load_from_db(session_id)
      else
        buffer
      end

    {:reply, buffer, state}
  end

  @impl true
  def handle_call({:discard, session_id}, _from, state) do
    # Clear from DB
    delete_from_db(session_id)
    # Clear from memory
    new_state = put_in(state.buffers[session_id], [])
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:flush, session_id}, _from, state) do
    # Get operations
    ops = Map.get(state.buffers, session_id)
    ops = if is_nil(ops), do: load_from_db(session_id), else: ops

    if Enum.empty?(ops) do
      {:reply, {:ok, 0}, state}
    else
      # In TALA v2, the actual execution of tools should be orchestrated.
      # For now, we return the operations so the caller (Tool Executor) can process them.
      # We mark them as 'flushed' in memory for now.
      new_state = put_in(state.buffers[session_id], [])
      {:reply, {:ok, ops}, new_state}
    end
  end

  # Helper Functions

  defp persist_operation(op) do
    %DiwaAgent.Tala.Operation{}
    |> DiwaAgent.Tala.Operation.changeset(op)
    |> Repo.insert()
  end

  defp load_from_db(session_id) do
    import Ecto.Query

    DiwaAgent.Tala.Operation
    |> where(session_id: ^session_id, status: "pending")
    |> order_by(asc: :inserted_at)
    |> Repo.all()
  end

  defp delete_from_db(session_id) do
    import Ecto.Query

    DiwaAgent.Tala.Operation
    |> where(session_id: ^session_id, status: "pending")
    |> Repo.delete_all()
  end
end

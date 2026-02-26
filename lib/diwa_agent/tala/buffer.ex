defmodule DiwaAgent.Tala.Buffer do
  @moduledoc """
  Transactional Accumulation & Lazy Apply (TALA) Buffer.
  Manages deferred operation commits for AI agents.
  """
  use GenServer
  require Logger
  alias DiwaAgent.Repo

  @max_ops Application.compile_env(:diwa_agent, [:tala, :max_buffer_ops], 500)
  @max_payload Application.compile_env(:diwa_agent, [:tala, :max_op_payload_bytes], 65_536)
  @warning_threshold 0.8  # Warn at 80% capacity

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
    # TALA Limit Enforcement: Check buffer capacity
    current_buffer = Map.get(state.buffers, session_id, [])
    current_count = length(current_buffer)
    
    cond do
      current_count >= @max_ops ->
        error_msg = """
        Buffer full (#{current_count}/#{@max_ops} operations).

        Your TALA buffer has reached capacity. To continue:
        - Run `/commit` to save all #{current_count} operations to database
        - Run `/discard` to abandon buffered operations
        - Run `/pending` to review what's in the buffer

        After clearing the buffer, you can continue adding operations.
        """
        {:reply, {:error, :buffer_full, error_msg}, state}
      
      true ->
        # TALA Limit Enforcement: Check payload size
        payload_size = estimate_payload_size(params)
        
        if payload_size > @max_payload do
          payload_kb = div(payload_size, 1024)
          limit_kb = div(@max_payload, 1024)
          
          error_msg = """
          Operation payload (#{payload_kb}KB) exceeds #{limit_kb}KB limit.

          This single operation is too large to buffer. Options:
          1. Split content into smaller operations
          2. Write directly without buffering (remove buffer=true)
          3. Reduce content size

          Note: The #{limit_kb}KB limit matches the maximum memory content size.
          """
          {:reply, {:error, :payload_too_large, error_msg}, state}
        else
          # Limits OK - proceed with operation
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
              new_buffer = current_buffer ++ [db_op]
              new_state = put_in(state.buffers[session_id], new_buffer)
              new_count = length(new_buffer)
              
              # 3. Add warning if approaching capacity
              warning = if new_count >= trunc(@max_ops * @warning_threshold) do
                "Buffer at #{trunc(new_count / @max_ops * 100)}% capacity (#{new_count}/#{@max_ops}). Consider running /commit soon."
              else
                nil
              end
              
              {:reply, {:ok, db_op.id, warning}, new_state}

            {:error, reason} ->
              Logger.error("[TALA] Failed to persist operation: #{inspect(reason)}")
              {:reply, {:error, reason}, state}
          end
        end
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

  defp estimate_payload_size(params) when is_map(params) do
    # Simple size estimation: JSON encode and count bytes
    # This is approximate but sufficient for limit checking
    case Jason.encode(params) do
      {:ok, json} -> byte_size(json)
      _ -> 0
    end
  end
  defp estimate_payload_size(_), do: 0
end

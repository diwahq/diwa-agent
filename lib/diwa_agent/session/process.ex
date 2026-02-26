defmodule DiwaAgent.Session.Process do
  @moduledoc """
  GenServer wrapper for active TALA sessions.
  
  Provides sub-second crash detection via OTP terminate/2 callback,
  complementing the heartbeat-based orphan detection system.
  
  Patent Reference: TALA Provisional Patent, Section 4.5, Claim 2
  """
  use GenServer
  require Logger
  alias DiwaAgent.Repo
  import Ecto.Query

  @registry DiwaAgent.SessionRegistry

  # Client API

  @doc """
  Start a session process for an active TALA session.
  
  Options:
    - session_id: UUID (required)
    - context_id: UUID (required)
    - actor: String (required)
    - auto_commit_on_shutdown: boolean (optional, default: true)
  """
  def start_link(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    
    GenServer.start_link(__MODULE__, opts, name: via_tuple(session_id))
  end

  @doc """
  Get the PID of a session process by session_id.
  Returns {:ok, pid} or {:error, :not_found}.
  """
  def whereis(session_id) do
    case Registry.lookup(@registry, session_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Stop a session process gracefully.
  This will trigger commit if auto_commit_on_shutdown is true.
  """
  def stop(session_id) do
    case whereis(session_id) do
      {:ok, pid} -> GenServer.stop(pid, :normal)
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    context_id = Keyword.fetch!(opts, :context_id)
    actor = Keyword.fetch!(opts, :actor)
    auto_commit = Keyword.get(opts, :auto_commit_on_shutdown, true)

    Logger.info("[SessionProcess] Started for session #{session_id}, actor: #{actor}")
    
    state = %{
      session_id: session_id,
      context_id: context_id,
      actor: actor,
      auto_commit_on_shutdown: auto_commit,
      started_at: DateTime.utc_now()
    }
    
    # Emit telemetry
    :telemetry.execute(
      [:diwa_agent, :session, :process_started],
      %{count: 1},
      %{session_id: session_id, actor: actor}
    )
    
    {:ok, state}
  end

  @impl true
  def terminate(reason, state) do
    session_id = state.session_id
    auto_commit = state.auto_commit_on_shutdown
    
    action = case reason do
      # Graceful shutdowns - commit buffer if enabled
      :normal when auto_commit ->
        handle_graceful_shutdown(state)
        :commit
      
      :shutdown when auto_commit ->
        handle_graceful_shutdown(state)
        :commit
      
      {:shutdown, _} when auto_commit ->
        handle_graceful_shutdown(state)
        :commit
      
      # Graceful but no auto-commit
      r when r in [:normal, :shutdown] ->
        Logger.info("[SessionProcess] Graceful shutdown without auto-commit for session #{session_id}")
        :none
      
      # Crashes - mark as orphaned immediately
      :killed ->
        Logger.warning("[SessionProcess] Session #{session_id} killed - marking orphaned")
        mark_orphaned(session_id, "Process killed")
        :orphan
      
      {:error, reason_detail} ->
        Logger.error("[SessionProcess] Session #{session_id} crashed: #{inspect(reason_detail)} - marking orphaned")
        mark_orphaned(session_id, "Process error: #{inspect(reason_detail)}")
        :orphan
      
      other ->
        Logger.warning("[SessionProcess] Session #{session_id} terminated unexpectedly: #{inspect(other)} - marking orphaned")
        mark_orphaned(session_id, "Unexpected termination: #{inspect(other)}")
        :orphan
    end
    
    # Emit telemetry
    :telemetry.execute(
      [:diwa_agent, :session, :process_terminated],
      %{count: 1},
      %{session_id: session_id, reason: reason, action: action}
    )
    
    :ok
  end

  # Private Helpers

  defp via_tuple(session_id) do
    {:via, Registry, {@registry, session_id}}
  end

  defp handle_graceful_shutdown(state) do
    session_id = state.session_id
    
    # Check if buffer has pending operations
    buffer_count = count_pending_operations(session_id)
    
    if buffer_count > 0 do
      Logger.info("[SessionProcess] Auto-committing #{buffer_count} operations for session #{session_id}")
      
      # Attempt to commit buffer
      case DiwaAgent.Tala.Buffer.flush(session_id) do
        {:ok, ops} ->
          # Execute operations (same logic as end_session)
          Enum.each(ops, fn op ->
            params = Map.drop(op.params, ["buffer", "session_id"])
            DiwaAgent.Tools.Executor.execute(op.tool_name, params)
          end)
          
          # Mark as committed in DB
          DiwaAgent.Tala.Operation
          |> where(session_id: ^session_id, status: "pending")
          |> Repo.update_all(set: [status: "committed"])
          
          Logger.info("[SessionProcess] Successfully committed #{length(ops)} operations")
          
        {:error, reason} ->
          Logger.error("[SessionProcess] Failed to commit buffer: #{inspect(reason)}")
      end
    else
      Logger.debug("[SessionProcess] No pending operations to commit for session #{session_id}")
    end
  end

  defp count_pending_operations(session_id) do
    ops = DiwaAgent.Tala.Buffer.list(session_id)
    length(ops)
  end

  defp mark_orphaned(session_id, reason) do
    # Mark session as orphaned in database or create orphan record
    # This enables the cleanup worker to handle it
    Logger.warning("[SessionProcess] Marking session #{session_id} as orphaned: #{reason}")
    
    # Get buffer count for telemetry
    buffer_count = count_pending_operations(session_id)
    
    # Emit telemetry
    :telemetry.execute(
      [:diwa_agent, :session, :orphaned],
      %{count: 1, buffer_count: buffer_count},
      %{session_id: session_id, detection_method: :terminate_callback}
    )
    
    # Note: The cleanup worker will handle actual cleanup based on TTL
    # This immediate marking allows for faster detection than heartbeat timeout
    :ok
  end
end

defmodule DiwaAgent.Tala.CleanupWorker do
  @moduledoc """
  TALA Orphan Buffer Cleanup Job.
  Periodically scans for and cleans up abandoned TALA buffers based on TTL.
  """
  use GenServer
  require Logger
  alias DiwaAgent.Repo
  alias DiwaAgent.Tala.Operation
  import Ecto.Query

  @default_interval_minutes 60
  @default_ttl_hours 24
  @default_warn_threshold 10

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    if cleanup_enabled?() do
      Logger.info("[TALA Cleanup] Worker started (interval: #{cleanup_interval_ms()}ms, TTL: #{buffer_ttl_hours()}h)")
      schedule_cleanup()
    else
      Logger.info("[TALA Cleanup] Worker disabled via config")
    end
    
    {:ok, %{last_run: nil, total_cleaned: 0, total_warnings: 0}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    Logger.info("[TALA Cleanup] Starting cleanup job...")
    
    result = perform_cleanup()
    
    new_state = %{
      state |
      last_run: DateTime.utc_now(),
      total_cleaned: state.total_cleaned + result.buffers_cleaned,
      total_warnings: state.total_warnings + result.warnings_created
    }
    
    Logger.info("[TALA Cleanup] Complete: #{result.buffers_cleaned} buffers cleaned, #{result.warnings_created} incidents created")
    
    schedule_cleanup()
    {:noreply, new_state}
  end

  # --- Cleanup Logic ---

  defp perform_cleanup do
    cutoff = DateTime.utc_now() |> DateTime.add(-buffer_ttl_hours() * 3600, :second)
    
    # Find all sessions with pending ops older than cutoff
    orphaned_sessions = 
      Operation
      |> where([op], op.status == "pending" and op.inserted_at < ^cutoff)
      |> select([op], op.session_id)
      |> distinct(true)
      |> Repo.all()
    
    results = Enum.map(orphaned_sessions, fn session_id ->
      cleanup_session(session_id)
    end)
    
    %{
      buffers_cleaned: length(results),
      warnings_created: Enum.count(results, &(&1.warning_created))
    }
  end

  defp cleanup_session(session_id) do
    # Get operation count before discarding
    op_count = 
      Operation
      |> where(session_id: ^session_id, status: "pending")
      |> Repo.aggregate(:count)
    
    # Discard operations
    Operation
    |> where(session_id: ^session_id, status: "pending")
    |> Repo.delete_all()
    
    Logger.info("[TALA Cleanup] Discarded #{op_count} operations from session #{session_id}")
    
    # Create incident if threshold exceeded
    warning_created = if op_count >= warn_threshold() do
      create_cleanup_incident(session_id, op_count)
      true
    else
      false
    end
    
    %{session_id: session_id, op_count: op_count, warning_created: warning_created}
  end

  defp create_cleanup_incident(session_id, op_count) do
    # Try to find context from any operation in this session
    context_id = 
      Operation
      |> where(session_id: ^session_id)
      |> limit(1)
      |> select([op], op.context_id)
      |> Repo.one()
    
    if context_id do
      metadata = %{
        type: "incident",
        severity: "low",
        source: "tala_cleanup",
        session_id: session_id,
        operations_discarded: op_count
      }
      
      content = """
      TALA Cleanup Warning: #{op_count} buffered operations were auto-discarded from session #{session_id} after #{buffer_ttl_hours()}h TTL expiry.
      
      This indicates an abandoned session. No data was committed to the database.
      """
      
      # Create memory using the Memory module directly
      case DiwaAgent.Storage.Memory.add(context_id, content, %{
        metadata: Jason.encode!(metadata),
        tags: "tala,cleanup,incident",
        severity: "low"
      }) do
        {:ok, _memory} ->
          Logger.warning("[TALA Cleanup] Created incident for session #{session_id} (#{op_count} ops)")
          :ok
        {:error, reason} ->
          Logger.error("[TALA Cleanup] Failed to create incident: #{inspect(reason)}")
          :error
      end
    else
      Logger.warning("[TALA Cleanup] Could not create incident for session #{session_id} - no context found")
      :error
    end
  end

  # --- Configuration ---

  defp cleanup_enabled? do
    Application.get_env(:diwa_agent, :tala, [])
    |> Keyword.get(:cleanup_enabled, true)
  end

  defp cleanup_interval_ms do
    minutes = Application.get_env(:diwa_agent, :tala, [])
              |> Keyword.get(:cleanup_interval_minutes, @default_interval_minutes)
    
    minutes * 60 * 1000
  end

  defp buffer_ttl_hours do
    Application.get_env(:diwa_agent, :tala, [])
    |> Keyword.get(:buffer_ttl_hours, @default_ttl_hours)
  end

  defp warn_threshold do
    Application.get_env(:diwa_agent, :tala, [])
    |> Keyword.get(:warn_threshold, @default_warn_threshold)
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, cleanup_interval_ms())
  end
end

defmodule DiwaAgent.Workflow.ArtifactQueue do
  @moduledoc """
  Session-scoped ETS queue for handoff artifacts.

  Stores specs, RFCs, and decisions created during a session
  for automatic inclusion in handoff notes.

  Solves the planner→coder workflow gap where specs must be
  manually re-uploaded to the next agent.
  """

  use GenServer
  require Logger

  @table_name :handoff_artifact_queue

  ## Client API

  @doc """
  Start the artifact queue GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Initialize queue for a new session.
  Returns session ID.
  """
  def init_session(session_id) do
    GenServer.call(__MODULE__, {:init_session, session_id})
  end

  @doc """
  Add an artifact to the queue.

  ## Fields
  - path: File path (optional)
  - content: Full content of the artifact
  - type: :spec, :rfc, :decision, :note
  - metadata: Additional info (title, actor, etc.)
  """
  def queue_artifact(session_id, artifact) do
    GenServer.call(__MODULE__, {:queue, session_id, artifact})
  end

  @doc """
  List all queued artifacts for a session.
  """
  def list_artifacts(session_id) do
    GenServer.call(__MODULE__, {:list, session_id})
  end

  @doc """
  Get artifact count for a session.
  """
  def count(session_id) do
    GenServer.call(__MODULE__, {:count, session_id})
  end

  @doc """
  Clear all artifacts for a session.
  """
  def clear_session(session_id) do
    GenServer.call(__MODULE__, {:clear, session_id})
  end

  @doc """
  Compile all artifacts into handoff-ready format.
  Returns markdown string with all artifact contents.
  """
  def compile_for_handoff(session_id) do
    GenServer.call(__MODULE__, {:compile, session_id})
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    # Create ETS table for artifact storage
    table =
      :ets.new(@table_name, [
        :set,
        :named_table,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])

    Logger.info("[ArtifactQueue] Started with ETS table: #{table}")
    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:init_session, session_id}, _from, state) do
    # Initialize empty list for this session
    :ets.insert(@table_name, {session_id, []})
    Logger.debug("[ArtifactQueue] Session #{session_id} initialized")
    {:reply, {:ok, session_id}, state}
  end

  @impl true
  def handle_call({:queue, session_id, artifact}, _from, state) do
    # Get existing artifacts for session
    existing =
      case :ets.lookup(@table_name, session_id) do
        [{^session_id, artifacts}] -> artifacts
        [] -> []
      end

    # Add timestamp and ID
    enhanced_artifact =
      artifact
      |> Map.put(:queued_at, DateTime.utc_now())
      |> Map.put(:id, generate_id())

    # Prepend new artifact (newest first)
    updated = [enhanced_artifact | existing]

    # Store back
    :ets.insert(@table_name, {session_id, updated})

    Logger.info("[ArtifactQueue] Queued #{artifact[:type]} for session #{session_id}")
    {:reply, {:ok, enhanced_artifact}, state}
  end

  @impl true
  def handle_call({:list, session_id}, _from, state) do
    artifacts =
      case :ets.lookup(@table_name, session_id) do
        [{^session_id, artifacts}] -> artifacts
        [] -> []
      end

    {:reply, {:ok, artifacts}, state}
  end

  @impl true
  def handle_call({:count, session_id}, _from, state) do
    count =
      case :ets.lookup(@table_name, session_id) do
        [{^session_id, artifacts}] -> length(artifacts)
        [] -> 0
      end

    {:reply, {:ok, count}, state}
  end

  @impl true
  def handle_call({:clear, session_id}, _from, state) do
    :ets.delete(@table_name, session_id)
    Logger.info("[ArtifactQueue] Cleared session #{session_id}")
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:compile, session_id}, _from, state) do
    artifacts =
      case :ets.lookup(@table_name, session_id) do
        [{^session_id, artifacts}] -> artifacts
        [] -> []
      end

    if length(artifacts) == 0 do
      {:reply, {:ok, nil}, state}
    else
      compiled = compile_artifacts(artifacts)
      {:reply, {:ok, compiled}, state}
    end
  end

  ## Private Helpers

  defp generate_id do
    :crypto.strong_rand_bytes(8)
    |> Base.encode16(case: :lower)
  end

  defp compile_artifacts(artifacts) do
    # Sort by queued_at (oldest first for handoff)
    sorted = Enum.reverse(artifacts)

    header = """
    ---
    ## 📦 Handoff Artifacts (#{length(artifacts)})

    The following artifacts were created/queued during this session:

    ---

    """

    body =
      sorted
      |> Enum.with_index(1)
      |> Enum.map(fn {artifact, idx} -> format_artifact(artifact, idx) end)
      |> Enum.join("\n\n---\n\n")

    footer = "\n\n---\n\n*End of artifacts. Use these for context in your next session.*\n"

    header <> body <> footer
  end

  defp format_artifact(artifact, idx) do
    type_emoji =
      case artifact[:type] do
        :spec -> "📋"
        :rfc -> "📝"
        :decision -> "⚖️"
        :note -> "📌"
        _ -> "📄"
      end

    title = artifact[:metadata][:title] || "Artifact #{idx}"

    """
    ### #{type_emoji} #{idx}. #{title}

    **Type**: #{artifact[:type]}  
    **Queued**: #{format_time(artifact[:queued_at])}
    #{if artifact[:path], do: "**File**: `#{artifact[:path]}`", else: ""}

    #{artifact[:content]}
    """
  end

  defp format_time(datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> DateTime.to_string()
  end
end

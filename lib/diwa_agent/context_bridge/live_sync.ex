defmodule DiwaAgent.ContextBridge.LiveSync do
  @moduledoc """
  Module 4: LiveSync
  Coordinates real-time activity logging and session management.
  """

  alias DiwaAgent.Repo
  alias DiwaAgent.Storage.Schemas.{Session, Memory}
  alias DiwaAgent.Delegation.Handoff
  require Logger

  @doc """
  Starts a new development session.
  """
  def start_session(context_id, actor, metadata \\ %{}) do
    attrs = %{
      context_id: context_id,
      actor: actor,
      started_at: DateTime.utc_now(),
      metadata: metadata
    }

    case %Session{} |> Session.changeset(attrs) |> Repo.insert() do
      {:ok, session} ->
        Logger.info("Session started: #{session.id} for actor #{actor}")
        {:ok, session}

      error ->
        error
    end
  end

  @doc """
  Logs an activity to the current session.
  """
  def log_activity(session_id, message, metadata \\ %{}) do
    # Currently we just log to standard logger or could add to session metadata
    # In a more advanced version, we might create 'activity' memories
    Logger.info("[Session #{session_id}] #{message} | #{inspect(metadata)}")

    # Optional: Update session metadata with 'active_files' etc
    if files = metadata[:active_files] do
      update_session_files(session_id, files)
    end

    :ok
  end

  defp update_session_files(session_id, new_files) do
    case Repo.get(Session, session_id) do
      nil ->
        :ok

      session ->
        current_meta = session.metadata || %{}
        existing_files = current_meta["active_files"] || []
        updated_files = (existing_files ++ new_files) |> Enum.uniq()

        session
        |> Session.changeset(%{metadata: Map.put(current_meta, "active_files", updated_files)})
        |> Repo.update()
    end
  end

  @doc """
  Ends a session and generates a handoff note.
  """
  def end_session(session_id, summary, next_steps \\ []) do
    case Repo.get(Session, session_id) do
      nil ->
        {:error, :not_found}

      session ->
        # Finalize session
        Repo.transaction(fn ->
          updated_session =
            session
            |> Session.changeset(%{ended_at: DateTime.utc_now(), summary: summary})
            |> Repo.update!()

          # Create Handoff Memory
          handoff_data =
            Handoff.new(%{
              context_id: session.context_id,
              from_agent_id: session.actor,
              task_definition: summary,
              next_steps: next_steps,
              active_files: session.metadata["active_files"] || []
            })

          memory_attrs = %{
            context_id: session.context_id,
            content: summary,
            actor: session.actor,
            memory_class: "handoff",
            priority: "high",
            lifecycle: "session",
            metadata: Handoff.to_metadata(handoff_data)
          }

          %Memory{}
          |> Memory.changeset(memory_attrs)
          |> Repo.insert!()

          updated_session
        end)
    end
  end
end

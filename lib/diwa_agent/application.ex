defmodule DiwaAgent.Application do
  @moduledoc """
  OTP Application for DiwaAgent.

  Starts the supervision tree with:
  - DiwaAgent.Repo (SQLite database)
  - DiwaAgent.Server (MCP stdio server)
  """

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children =
      [
        # Database
        DiwaAgent.Repo,

        # Task Supervisor for async tasks
        {Task.Supervisor, name: DiwaAgent.TaskSupervisor},

        # Agent and Shortcut Registries
        DiwaAgent.Registry.Server,
        DiwaAgent.Shortcuts.Registry,
        DiwaAgent.Delegation.Broker,

        # Cloud Synchronization Worker
        DiwaAgent.Cloud.SyncWorker,

        # TALA Buffer (Transactional Accumulation & Lazy Apply)
        DiwaAgent.Tala.Buffer,

        # Handoff Artifact Queue
        DiwaAgent.Workflow.ArtifactQueue,

        # MCP Server (Must start before Transport to handle initial messages)
        DiwaAgent.Server,

        # Transport (Stdio)
        # Only start if not disabled via env var (e.g. when running in Diwa Cloud)
        if System.get_env("DIWA_DISABLE_TRANSPORT") != "true" do
          {DiwaAgent.Transport.Stdio, []}
        else
          nil
        end
      ]
      |> Enum.reject(&is_nil(&1))

    opts = [strategy: :one_for_one, name: DiwaAgent.Supervisor]

    # Run migrations if configured
    if Application.get_env(:diwa_agent, :auto_migrate, false) do
      migrate()
    end

    # Create default organization if configured
    if Application.get_env(:diwa_agent, :create_default_org, false) do
      create_default_org()
    end

    Supervisor.start_link(children, opts)
  end

  defp migrate do
    # Run migrations on startup (for escript/release mode)
    # Suppress all output to prevent stdout pollution in MCP protocol
    # and ensure any residual logs go to stderr
    Logger.configure(level: :warning)
    Logger.configure_backend(:console, device: :standard_error)

    try do
      # Note: with_repo/2 takes an optional logger option since Ecto 3.9
      # but if not available we rely on Logger.configure_backend
      {:ok, _, _} =
        Ecto.Migrator.with_repo(DiwaAgent.Repo, fn repo ->
          # Log via Logger
          Ecto.Migrator.run(repo, :up, all: true, log: :debug)
        end)
    rescue
      e ->
        # Log to stderr only
        Logger.error("[DiwaAgent] Migration failed: #{Exception.message(e)}")
        :ok
    end
  end

  defp create_default_org do
    # Create default org if none exists
    # Implementation in DiwaAgent.Storage.Organizations
    :ok
  end
end

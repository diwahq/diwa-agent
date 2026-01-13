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
    children = [
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

      # MCP Server (Must start before Transport to handle initial messages)
      DiwaAgent.Server,

      # Transport (Stdio)
      DiwaAgent.Transport.Stdio
    ]

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
    Logger.configure(level: :none)
    
    try do
      {:ok, _, _} = Ecto.Migrator.with_repo(DiwaAgent.Repo, &Ecto.Migrator.run(&1, :up, all: true))
    rescue
      e ->
        # Log to stderr only
        Logger.configure(level: :warning)
        Logger.error("[DiwaAgent] Migration failed: #{Exception.message(e)}")
        :ok
    after
      Logger.configure(level: :warning)
    end
  end

  defp create_default_org do
    # Create default org if none exists
    # Implementation in DiwaAgent.Storage.Organizations
    :ok
  end
end

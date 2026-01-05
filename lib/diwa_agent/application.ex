defmodule DiwaAgent.Application do
  @moduledoc """
  OTP Application for DiwaAgent.

  Starts the supervision tree with:
  - DiwaAgent.Repo (SQLite database)
  - DiwaAgent.Server (MCP stdio server)
  """

  use Application

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

      # Transport (Stdio)
      DiwaAgent.Transport.Stdio,

      # MCP Server
      DiwaAgent.Server
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
    {:ok, _, _} = Ecto.Migrator.with_repo(DiwaAgent.Repo, &Ecto.Migrator.run(&1, :up, all: true))
  rescue
    # Ignore migration errors on startup
    _ -> :ok
  end

  defp create_default_org do
    # Create default org if none exists
    # Implementation in DiwaAgent.Storage.Organizations
    :ok
  end
end

import Config

adapter = Application.get_env(:diwa_agent, DiwaAgent.Repo)[:adapter]

if adapter == Ecto.Adapters.Postgres do
  database_url =
    System.get_env("DATABASE_URL") ||
      if config_env() == :prod do
        raise """
        environment variable DATABASE_URL is missing.
        For example: postgres://username:password@localhost/diwa_agent
        """
      else
        nil
      end

  if database_url do
    config :diwa_agent, DiwaAgent.Repo,
      url: database_url,
      pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
  end
else
  # SQLite
  database_path =
    System.get_env("DATABASE_PATH") ||
      Application.get_env(:diwa_agent, DiwaAgent.Repo)[:database]

  config :diwa_agent, DiwaAgent.Repo, database: database_path
end

if config_env() == :prod do
  # Log level from env
  log_level =
    System.get_env("DIWA_AGENT_LOG_LEVEL", "info")
    |> String.to_atom()

  config :logger, level: log_level
end

# Future: Cloud hybrid mode
# if cloud_url = System.get_env("DIWA_CLOUD_URL") do
#   config :diwa_agent,
#     health_engine: DiwaAgent.Engines.Health.CloudAdapter,
#     ace_engine: DiwaAgent.Engines.ACE.CloudAdapter,
#     conflict_engine: DiwaAgent.Engines.Conflict.CloudAdapter,
#     cloud_url: cloud_url,
#     cloud_api_key: System.get_env("DIWA_CLOUD_API_KEY")
# end

import Config

if config_env() == :prod do
  database_path =
    System.get_env("DIWA_AGENT_DATABASE_PATH") ||
      "priv/diwa_agent.db"

  config :diwa_agent, DiwaAgent.Repo,
    database: database_path

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

import Config

config :diwa_agent, DiwaAgent.Repo,
  database: "priv/diwa_agent_dev.db",
  show_sensitive_data_on_connection_error: true,
  stacktrace: true

config :logger,
  level: :warning

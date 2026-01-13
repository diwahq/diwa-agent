import Config

config :diwa_agent, DiwaAgent.Repo,
  adapter: Ecto.Adapters.SQLite3,
  database: "priv/diwa_agent_dev.db",
  pool_size: 10,
  show_sensitive_data_on_connection_error: true

config :logger,
  level: :warning

import Config

config :diwa_agent, DiwaAgent.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "ei",
  password: "",
  hostname: "localhost",
  database: "diwa_dev",
  show_sensitive_data_on_connection_error: true,
  stacktrace: true,
  pool_size: 10

config :logger,
  level: :warning

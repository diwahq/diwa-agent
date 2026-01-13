import Config

config :diwa_agent, DiwaAgent.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "ei",
  password: "",
  database: "diwa_dev",
  hostname: "127.0.0.1",
  pool_size: 10

config :logger,
  level: :warning

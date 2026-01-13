import Config

config :diwa_agent, DiwaAgent.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "ei",
  password: "",
  database: "diwa_dev",
  hostname: "localhost",
  pool_size: 10

config :logger,
  level: :warning

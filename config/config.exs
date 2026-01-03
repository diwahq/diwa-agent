import Config

config :diwa_agent,
  ecto_repos: [DiwaAgent.Repo],

  # Engine adapters (stub implementations in community edition)
  health_engine: DiwaAgent.Engines.Health.StubAdapter,
  ace_engine: DiwaAgent.Engines.ACE.StubAdapter,
  conflict_engine: DiwaAgent.Engines.Conflict.StubAdapter,
  cluster_adapter: DiwaAgent.Engines.Cluster.StubAdapter,

  # Feature flags
  auto_migrate: true,
  create_default_org: true

config :diwa_agent, DiwaAgent.Repo,
  database: "priv/diwa_agent.db",
  pool_size: 5

config :logger,
  level: :warning,
  backends: [:console]

config :logger, :console,
  device: :stderr,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

import_config "#{config_env()}.exs"

import Config

config :diwa_agent,
  ecto_repos: [DiwaAgent.Repo],
  vector_type: Pgvector.Ecto.Vector,
  engine_adapter: DiwaAgent.Engine.Simple,
  enable_analysis: true,

  # Engine adapters (stub implementations in community edition)
  health_engine: DiwaAgent.Engines.Health.StubAdapter,
  ace_engine: DiwaAgent.Engines.ACE.StubAdapter,
  conflict_engine: DiwaAgent.Engines.Conflict.StubAdapter,
  cluster_adapter: DiwaAgent.Engines.Cluster.StubAdapter,
  cloud_adapter: DiwaAgent.Cloud.StubAdapter,
  cloud_api_url: "https://api.diwa.one",

  # Feature flags
  # Disable to prevent slow startup on escript
  auto_migrate: true,
  create_default_org: true,

  # Edition control - Community Edition licensing (Apache 2.0)
  # Enterprise features (Patents D1, D2, D3, SINAG) are in diwa-cloud (BSL 1.1)
  enterprise_features: false

config :diwa_agent, DiwaAgent.Repo,
  adapter: Ecto.Adapters.SQLite3,
  migration_primary_key: [name: :id, type: :binary_id],
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

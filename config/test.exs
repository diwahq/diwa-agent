import Config

config :diwa_agent, DiwaAgent.Repo,
  database: "priv/diwa_agent_test.db",
  pool: Ecto.Adapters.SQL.Sandbox

config :logger,
  level: :warning

config :diwa_agent,
  vector_repo_module: DiwaAgent.Test.FakeVectorRepo,
  embedding_module: DiwaAgent.Test.FakeEmbeddings,
  consensus_module: DiwaAgent.Consensus.ClusterMock

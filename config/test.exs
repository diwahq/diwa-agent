import Config

config :diwa_agent, DiwaAgent.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "ei",
  password: "",
  hostname: "localhost",
  database: "diwa_agent_test",
  pool: Ecto.Adapters.SQL.Sandbox

config :logger,
  level: :warning

config :diwa_agent,
  vector_repo_module: DiwaAgent.Test.FakeVectorRepo,
  embedding_module: DiwaAgent.Test.FakeEmbeddings,
  consensus_module: DiwaAgent.Consensus.ClusterMock

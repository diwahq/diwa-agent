Postgrex.Types.define(
  DiwaAgent.PostgresTypes,
  [Pgvector.Extensions.Vector] ++ Ecto.Adapters.Postgres.extensions(),
  json: Jason
)

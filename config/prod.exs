import Config

# In production, we always use Postgres
config :diwa_agent, DiwaAgent.Repo,
  adapter: Ecto.Adapters.Postgres,
  types: DiwaAgent.PostgrexTypes

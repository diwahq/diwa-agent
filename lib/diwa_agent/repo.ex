defmodule DiwaAgent.Repo do
  use Ecto.Repo,
    otp_app: :diwa_agent,
    adapter: Ecto.Adapters.Postgres,
    types: DiwaAgent.PostgrexTypes  # ← Add this line if missing
end
defmodule DiwaAgent.Repo do
  use Ecto.Repo,
    otp_app: :diwa_agent,
    adapter: Ecto.Adapters.Postgres  # ← Add this line if missing
end
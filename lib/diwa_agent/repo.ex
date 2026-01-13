defmodule DiwaAgent.Repo do
  use Ecto.Repo,
    otp_app: :diwa_agent,
    adapter: Application.compile_env!(:diwa_agent, [DiwaAgent.Repo, :adapter])
end
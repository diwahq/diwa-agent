ExUnit.start()
{:ok, _} = DiwaAgent.Test.FakeVectorRepo.start_link()

# ExUnit.start() is already called at top




# Setup Ecto Sandbox
Ecto.Adapters.SQL.Sandbox.mode(DiwaAgent.Repo, :manual)

defmodule DiwaAgent.TestHelper do
  @moduledoc """
  Helper functions for tests.
  """

  @doc """
  Setup a test database checkout.
  """
  def setup_test_db do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(DiwaAgent.Repo)
    # Organization check in Context.ex will need this org to exist
    case DiwaAgent.Repo.get_by(DiwaAgent.Storage.Schemas.Organization, name: "Default") do
      nil ->
        %DiwaAgent.Storage.Schemas.Organization{}
        |> DiwaAgent.Storage.Schemas.Organization.changeset(%{name: "Default"})
        |> DiwaAgent.Repo.insert!()

      org ->
        org
    end

    :ok
  end

  @doc """
  Required to match the old API but does nothing for Postgres sandbox.
  """
  def start_database do
    :ok
  end

  @doc """
  Cleanup test database.
  """
  def cleanup_test_db(_path_placeholder) do
    Ecto.Adapters.SQL.Sandbox.checkin(DiwaAgent.Repo)
  end

  @doc """
  Old signature compatibility.
  """
  def stop_database do
    :ok
  end
end

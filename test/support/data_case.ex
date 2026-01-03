defmodule DiwaAgent.DataCase do
  @moduledoc """
  This module defines the setup for tests that require
  access to the application's data layer.
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      alias DiwaAgent.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import DiwaAgent.DataCase
    end
  end

  setup tags do
    DiwaAgent.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(DiwaAgent.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end
end

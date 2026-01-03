defmodule DiwaAgent.Storage.Organization do
  @moduledoc """
  CRUD operations for Organizations (Multi-Tenancy) using Ecto.
  """

  alias DiwaAgent.Repo
  alias DiwaAgent.Storage.Schemas.Organization
  import Ecto.Query

  @doc """
  Create a new organization.
  """
  def create(name, tier \\ "free") do
    %Organization{}
    |> Organization.changeset(%{name: name, tier: tier})
    |> Repo.insert()
  end

  @doc """
  Get the default organization or create it if missing.
  """
  def get_default_org do
    case Repo.one(from(o in Organization, where: o.name == "Global", limit: 1)) do
      nil -> create("Global", "enterprise")
      org -> {:ok, org}
    end
  end

  @doc """
  List all organizations.
  """
  def list do
    {:ok, Repo.all(Organization)}
  end

  @doc """
  Get an organization by ID.
  """
  def get(id) do
    case Repo.get(Organization, id) do
      nil -> {:error, :not_found}
      org -> {:ok, org}
    end
  end
end

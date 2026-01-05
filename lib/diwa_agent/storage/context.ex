defmodule DiwaAgent.Storage.Context do
  @moduledoc """
  CRUD operations for development contexts using Ecto and PostgreSQL.
  """

  alias DiwaAgent.Repo
  alias DiwaAgent.Storage.Schemas.{Context, Organization}
  import Ecto.Query
  require Logger

  @type context :: %{
          id: String.t(),
          name: String.t(),
          description: String.t() | nil,
          organization_id: String.t(),
          health_score: integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @doc """
  Create a new context.
  """
  def create(name, description \\ nil, organization_id \\ nil) do
    organization_id = organization_id || get_default_organization_id()

    attrs = %{
      name: name,
      description: description,
      organization_id: organization_id
    }

    %Context{}
    |> Context.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  List all contexts for an organization.
  """
  def list(organization_id \\ nil) do
    organization_id = organization_id || get_default_organization_id()

    query =
      from(c in Context,
        where: c.organization_id == ^organization_id,
        order_by: [asc: c.inserted_at]
      )

    {:ok, Repo.all(query)}
  end

  @doc """
  Get a specific context by ID.
  """
  def get(nil), do: {:error, :not_found}

  def get(id) do
    with {:ok, uuid} <- cast_uuid(id) do
      case Repo.get(Context, uuid) do
        nil -> {:error, :not_found}
        context -> {:ok, context}
      end
    else
      :error -> raise Ecto.Query.CastError, type: Ecto.UUID, value: id, message: "invalid UUID"
    end
  end

  defp cast_uuid(nil), do: :error

  defp cast_uuid(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> {:ok, uuid}
      _ -> :error
    end
  end

  @doc """
  Update a context.
  """
  def update(nil, _), do: {:error, :not_found}

  def update(id, updates) do
    case Repo.get(Context, id) do
      nil ->
        {:error, :not_found}

      context ->
        context
        |> Context.changeset(updates)
        |> Repo.update()
    end
  end

  @doc """
  Delete a context.
  """
  def delete(nil), do: {:error, :not_found}

  def delete(id) do
    case Repo.get(Context, id) do
      nil ->
        {:error, :not_found}

      context ->
        Repo.delete(context)
        :ok
    end
  end

  @doc """
  Count contexts.
  """
  def count(organization_id \\ nil) do
    organization_id = organization_id || get_default_organization_id()

    query =
      from(c in Context,
        where: c.organization_id == ^organization_id,
        select: count(c.id)
      )

    {:ok, Repo.one(query)}
  end

  @doc """
  Find a context by name (case-insensitive).
  Returns {:ok, context} or {:error, :not_found}.
  """
  def find_by_name(name, organization_id \\ nil) do
    organization_id = organization_id || get_default_organization_id()

    # First try exact match
    query_exact =
      from(c in Context,
        where: c.organization_id == ^organization_id and c.name == ^name
      )

    case Repo.one(query_exact) do
      %Context{} = ctx ->
        {:ok, ctx}

      nil ->
        # Try case-insensitive match
        query_ilike =
          from(c in Context,
            where:
              c.organization_id == ^organization_id and
                fragment("lower(?)", c.name) == ^String.downcase(name)
          )

        case Repo.one(query_ilike) do
          %Context{} = ctx ->
            {:ok, ctx}

          nil ->
            # Try searching by ID if the name looks like a UUID
            if is_uuid?(name) do
              get(name)
            else
              {:error, :not_found}
            end
        end
    end
  end

  defp is_uuid?(str) do
    case Ecto.UUID.cast(str) do
      {:ok, _} -> true
      _ -> false
    end
  end

  # Helpers

  defp get_default_organization_id do
    # For now, ensure a default organization exists and return its ID
    case Repo.one(from(o in Organization, where: o.name == "Default", select: o.id)) do
      nil ->
        {:ok, org} =
          %Organization{}
          |> Organization.changeset(%{name: "Default"})
          |> Repo.insert()

        org.id

      id ->
        id
    end
  end
end

defmodule DiwaAgent.Storage.MemoryVersion do
  @moduledoc """
  CRUD operations for memory versions.
  """
  alias DiwaAgent.Repo
  alias DiwaSchema.Core.MemoryVersion
  import Ecto.Query

  @doc """
  Record a new version of a memory.
  """
  def record(memory, operation, opts \\ %{}) do
    version_number = 
      (from(v in MemoryVersion, 
        where: v.memory_id == ^memory.id, 
        select: coalesce(max(v.version_number), 0) + 1) 
      |> Repo.one())

    attrs = %{
      memory_id: memory.id,
      content: memory.content,
      tags: memory.tags || [],
      metadata: memory.metadata || %{},
      operation: operation,
      actor: opts[:actor] || memory.actor,
      reason: opts[:reason],
      parent_version_id: opts[:parent_version_id],
      version_number: version_number
    }

    %MemoryVersion{}
    |> MemoryVersion.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  List history of a specific memory.
  """
  def list_history(memory_id) do
    query =
      from(v in MemoryVersion,
        where: v.memory_id == ^memory_id,
        order_by: [desc: v.inserted_at]
      )

    {:ok, Repo.all(query)}
  end

  @doc """
  Get a specific version by ID.
  """
  def get(id) do
    case Repo.get(MemoryVersion, id) do
      nil -> {:error, :not_found}
      version -> {:ok, version}
    end
  end

  @doc """
  Get the latest version of a memory.
  """
  def get_latest(memory_id) do
    query =
      from(v in MemoryVersion,
        where: v.memory_id == ^memory_id,
        order_by: [desc: v.inserted_at],
        limit: 1
      )

    case Repo.one(query) do
      nil -> {:error, :not_found}
      version -> {:ok, version}
    end
  end

  @doc """
  List recent changes (versions) across a context.
  """
  def list_recent_changes(context_id, limit \\ 20) do
    query =
      from(v in MemoryVersion,
        join: m in assoc(v, :memory),
        where: m.context_id == ^context_id,
        order_by: [desc: v.inserted_at],
        limit: ^limit,
        preload: [:memory]
      )

    {:ok, Repo.all(query)}
  end
end

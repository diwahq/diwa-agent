defmodule DiwaAgent.Storage.Memory do
  @moduledoc """
  CRUD operations for memories within contexts using Ecto and PostgreSQL.
  Includes versioning and soft-delete support.
  """

  alias DiwaAgent.Repo
  alias DiwaSchema.Core.Memory
  alias DiwaSchema.Core.Context
  alias DiwaAgent.Storage.MemoryVersion
  import Ecto.Query
  require Logger

  @embedding_module Application.compile_env(
                      :diwa_agent,
                      :embedding_module,
                      DiwaAgent.AI.Embeddings
                    )
  @vector_repo_module Application.compile_env(
                        :diwa_agent,
                        :vector_repo_module,
                        DiwaAgent.Storage.PgVectorRepo
                      )

  @type memory :: %{
          id: String.t(),
          context_id: String.t(),
          content: String.t(),
          metadata: map(),
          actor: String.t() | nil,
          project: String.t() | nil,
          tags: [String.t()],
          parent_id: String.t() | nil,
          external_ref: String.t() | nil,
          severity: String.t() | nil,
          deleted_at: DateTime.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @doc """
  Add a new memory to a context.
  """
  def add(context_id, content, opts \\ %{})
  def add(nil, _content, _opts), do: {:error, :context_not_found}

  def add(context_id, content, opts) do
    opts = normalize_opts(opts)
    raw_metadata = Map.get(opts, :metadata) || %{}

    with {:ok, metadata} <- decode_safe(raw_metadata) do
      metadata = metadata || %{}
      tags = normalize_tags(Map.get(opts, :tags))

      # Automated Classification (Module 2)
      {:ok, class, priority, lifecycle} =
        DiwaAgent.ContextBridge.MemoryClassification.classify(content)

      attrs = %{
        context_id: context_id,
        content: content,
        metadata: metadata,
        actor: Map.get(opts, :actor),
        project: Map.get(opts, :project),
        tags: tags,
        parent_id: Map.get(opts, :parent_id),
        external_ref: Map.get(opts, :external_ref),
        severity: Map.get(opts, :severity),
        # Context Bridge Fields
        memory_class: Map.get(opts, :memory_class) || Atom.to_string(class),
        priority: Map.get(opts, :priority) || Atom.to_string(priority),
        lifecycle: Map.get(opts, :lifecycle) || Atom.to_string(lifecycle),
        confidence: Map.get(opts, :confidence, 1.0),
        source: Map.get(opts, :source)
      }

      # attrs = add_embedding(attrs, content)

      case Repo.get(Context, context_id) do
        nil ->
          {:error, :context_not_found}

        _context ->
          Repo.transaction(fn ->
            case %Memory{} |> Memory.changeset(attrs) |> Repo.insert() do
              {:ok, memory} ->
                MemoryVersion.record(memory, "create", %{
                  actor: attrs.actor,
                  reason: Map.get(opts, :reason)
                })

                update_context_timestamp(context_id)
                memory

              {:error, changeset} ->
                Repo.rollback(changeset)
            end
          end)
          |> case do
            {:ok, memory} ->
              spawn_embedding_task(memory, content)
              spawn_cloud_sync_task(memory)
              {:ok, memory}

            {:error, %Ecto.Changeset{} = cs} ->
              {:error, cs}

            other ->
              other
          end
      end
    else
      {:error, _} -> {:error, :invalid_metadata}
    end
  end

  @doc """
  List all memories in a context (active only).
  """
  def list(context_id, opts \\ []) do
    # Validate context_id is a valid UUID before building the query
    case Ecto.UUID.cast(context_id) do
      {:ok, valid_uuid} ->
        limit = Keyword.get(opts, :limit, 100)
        offset = Keyword.get(opts, :offset, 0)
        include_deleted = Keyword.get(opts, :include_deleted, false)

        query =
          from(m in Memory,
            where: m.context_id == ^valid_uuid,
            order_by: [desc: m.inserted_at],
            limit: ^limit,
            offset: ^offset
          )

        query = if include_deleted, do: query, else: where(query, [m], is_nil(m.deleted_at))

        {:ok, Repo.all(query)}

      :error ->
        Logger.warning("Invalid context_id provided to Memory.list/2: #{inspect(context_id)}")
        {:error, :invalid_context_id}
    end
  end

  @doc """
  Get a specific memory by ID.
  """
  def get(id) do
    with {:ok, uuid} <- cast_uuid(id) do
      case Repo.get(Memory, uuid) do
        nil -> {:error, :not_found}
        memory -> {:ok, memory}
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

  @doc false
  defp validate_context_id(nil), do: {:ok, nil}

  defp validate_context_id(context_id) do
    case Ecto.UUID.cast(context_id) do
      {:ok, valid_uuid} ->
        {:ok, valid_uuid}

      :error ->
        Logger.warning("Invalid context_id UUID: #{inspect(context_id)}")
        {:error, :invalid_context_id}
    end
  end

  @doc """
  Update a memory's content.
  """
  def update(id, content, opts \\ %{}) do
    case Repo.get(Memory, id) do
      nil ->
        {:error, :not_found}

      memory ->
        changes = %{content: content}
        # changes = add_embedding(changes, content)

        Repo.transaction(fn ->
          case memory |> Memory.changeset(changes) |> Repo.update() do
            {:ok, updated} ->
              spawn_embedding_task(updated, content)

              MemoryVersion.record(updated, "update", %{
                actor: opts[:actor],
                reason: opts[:reason]
              })

              update_context_timestamp(updated.context_id)
              spawn_cloud_sync_task(updated)
              updated

            {:error, cs} ->
              Repo.rollback(cs)
          end
        end)
    end
  end

  @doc """
  Update a memory's metadata.
  """
  def update_metadata(id, metadata, opts \\ %{}) do
    with {:ok, metadata_map} <- decode_safe(metadata) do
      if is_map(metadata_map) do
        case Repo.get(Memory, id) do
          nil ->
            {:error, :not_found}

          memory ->
            Repo.transaction(fn ->
              case memory |> Memory.changeset(%{metadata: metadata_map}) |> Repo.update() do
                {:ok, updated} ->
                  MemoryVersion.record(updated, "update", %{
                    actor: opts[:actor],
                    reason: opts[:reason] || "Metadata update"
                  })

                  updated

                {:error, cs} ->
                  Repo.rollback(cs)
              end
            end)
        end
      else
        {:error, :invalid_metadata}
      end
    else
      {:error, _} -> {:error, :invalid_metadata}
    end
  end

  @doc """
  Soft-delete a memory.
  """
  def delete(id, opts \\ %{}) do
    case Repo.get(Memory, id) do
      nil ->
        {:error, :not_found}

      memory ->
        Repo.transaction(fn ->
          case memory |> Memory.changeset(%{deleted_at: DateTime.utc_now()}) |> Repo.update() do
            {:ok, updated} ->
              MemoryVersion.record(updated, "delete", %{
                actor: opts[:actor],
                reason: opts[:reason]
              })

              update_context_timestamp(updated.context_id)
              :ok

            {:error, cs} ->
              Repo.rollback(cs)
          end
        end)
    end
  end

  @doc """
  Restore a soft-deleted memory.
  """
  def restore(id, opts \\ %{}) do
    case Repo.get(Memory, id) do
      nil ->
        {:error, :not_found}

      memory ->
        Repo.transaction(fn ->
          case memory |> Memory.changeset(%{deleted_at: nil}) |> Repo.update() do
            {:ok, updated} ->
              MemoryVersion.record(updated, "restore", %{
                actor: opts[:actor],
                reason: opts[:reason] || "Restored from history"
              })

              updated

            {:error, cs} ->
              Repo.rollback(cs)
          end
        end)
    end
  end

  @doc """
  Search memories (active only).
  """
  def search(query_str, context_id \\ nil) do
    # Try vector search first via configured modules
    with {:ok, query_vec} <- @embedding_module.generate_embedding(query_str),
         {:ok, results} <- @vector_repo_module.search(query_vec, 20, context_id: context_id) do
      # Extract IDs and similarity scores
      # results is list of %{id: id, similarity: score, ...}
      results = Enum.filter(results, fn r -> r.similarity >= 0.25 end)
      id_map = Map.new(results, fn r -> {r.id, r.similarity} end)
      ids = Map.keys(id_map)

      base_query = from(m in Memory, where: m.id in ^ids)

      final_query =
        if context_id do
          from(m in base_query, where: m.context_id == ^context_id)
        else
          base_query
        end

      final_query
      |> Repo.all()
      |> Enum.sort_by(fn m -> id_map[m.id] end, :desc)
      |> then(fn
        [] -> search_text(query_str, context_id)
        results -> {:ok, results}
      end)
    else
      _ ->
        # Fallback to Postgres FTS
        search_text(query_str, context_id)
    end
  end

  def search_text(query_str, context_id \\ nil) do
    with {:ok, valid_context_id} <- validate_context_id(context_id) do
      adapter = Application.get_env(:diwa_agent, DiwaAgent.Repo)[:adapter]

      base_query =
        from(m in Memory,
          where: is_nil(m.deleted_at),
          limit: 50
        )

      base_query =
        if adapter == Ecto.Adapters.Postgres do
          from(m in base_query, where: ilike(m.content, ^"%#{query_str}%"))
        else
          from(m in base_query,
            where: fragment("lower(?) LIKE ?", m.content, ^"%#{String.downcase(query_str)}%")
          )
        end

      query =
        if valid_context_id,
          do: where(base_query, [m], m.context_id == ^valid_context_id),
          else: base_query

      {:ok, Repo.all(query)}
    end
  end

  @doc """
  Fuzzy search fallback using Jaro-Winkler on memory content.
  """
  def fuzzy_search(query_str, context_id \\ nil) do
    with {:ok, valid_context_id} <- validate_context_id(context_id) do
      # Only search recent or limited set to avoid performance issues
      limit = 200

      base_query =
        from(m in Memory,
          where: is_nil(m.deleted_at),
          order_by: [desc: m.inserted_at],
          limit: ^limit
        )

      query =
        if valid_context_id,
          do: where(base_query, [m], m.context_id == ^valid_context_id),
          else: base_query

      memories = Repo.all(query)

      scored =
        memories
        |> Enum.map(fn m ->
          # Check both content and optional metadata (like tags/title if any)
          score = DiwaAgent.Utils.Fuzzy.jaro_winkler(query_str, String.slice(m.content, 0, 100))
          {m, score}
        end)
        |> Enum.filter(fn {_, score} -> score >= 0.65 end)
        |> Enum.sort_by(fn {_, score} -> score end, :desc)
        |> Enum.map(&elem(&1, 0))

      {:ok, scored}
    end
  end

  @doc """
  Count total memories in a context.
  """
  def count(context_id) do
    with {:ok, valid_context_id} <- validate_context_id(context_id) do
      query =
        from(m in Memory, where: m.context_id == ^valid_context_id, where: is_nil(m.deleted_at))

      {:ok, Repo.aggregate(query, :count, :id)}
    end
  end

  @doc """
  List memories by type (e.g., 'handoff', 'decision').
  """
  def list_by_type(context_id, type) do
    with {:ok, valid_context_id} <- validate_context_id(context_id) do
      # Check configured adapter (defaulting to SQLite path if not Postgres)
      adapter = Application.get_env(:diwa_agent, DiwaAgent.Repo)[:adapter]

      query =
        from(m in Memory,
          where: m.context_id == ^valid_context_id,
          where: is_nil(m.deleted_at),
          order_by: [desc: m.inserted_at]
        )

      query =
        if adapter == Ecto.Adapters.Postgres do
          # Postgres JSONB syntax
          from(m in query, where: fragment("?->>'type' = ?", m.metadata, ^type))
        else
          # SQLite syntax
          from(m in query, where: fragment("json_extract(?, '$.type') = ?", m.metadata, ^type))
        end

      {:ok, Repo.all(query)}
    end
  end

  @doc """
  List memories containing a specific tag.
  """
  def list_by_tag(context_id, tag) do
    with {:ok, valid_context_id} <- validate_context_id(context_id) do
      query =
        from(m in Memory,
          where: m.context_id == ^valid_context_id,
          where: is_nil(m.deleted_at),
          where: ^tag in m.tags,
          order_by: [desc: m.inserted_at]
        )

      {:ok, Repo.all(query)}
    end
  end

  @doc """
  Find similar memories using vector similarity.
  """
  def find_similar(_embedding, _context_id \\ nil, _threshold \\ 0.5) do
    {:error, :vector_search_disabled}
  end

  @doc """
  Link a memory to a parent memory.
  """
  def set_parent(memory_id, parent_id) do
    case Repo.get(Memory, memory_id) do
      nil ->
        {:error, :not_found}

      memory ->
        memory
        |> Memory.changeset(%{parent_id: parent_id})
        |> Repo.update()
    end
  end

  @doc """
  Get all children of a memory.
  """
  def get_children(parent_id) do
    query = from(m in Memory, where: m.parent_id == ^parent_id, where: is_nil(m.deleted_at))
    {:ok, Repo.all(query)}
  end

  @doc """
  Roll back a memory to a specific version.
  """
  def rollback(memory_id, version_id, opts \\ %{}) do
    Repo.transaction(fn ->
      with {:ok, version} <- MemoryVersion.get(version_id),
           {:ok, memory} <- get(memory_id) do
        if version.memory_id != memory.id, do: Repo.rollback(:mismatched_memory)

        changes = %{
          content: version.content,
          tags: version.tags,
          metadata: version.metadata,
          deleted_at: nil
        }

        # changes = add_embedding(changes, version.content)

        case memory |> Memory.changeset(changes) |> Repo.update() do
          {:ok, updated} ->
            spawn_embedding_task(updated, version.content)

            MemoryVersion.record(updated, "rollback", %{
              actor: opts[:actor],
              reason: opts[:reason] || "Rollback to version #{version_id}",
              parent_version_id: version_id
            })

            updated

          {:error, cs} ->
            Repo.rollback(cs)
        end
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp spawn_cloud_sync_task(memory) do
    if System.get_env("DIWA_ENABLE_CLOUD_SYNC") == "true" do
      # Convert memory struct to a plain map for JSON serialization in the queue
      payload = %{
        id: memory.id,
        context_id: memory.context_id,
        content: memory.content,
        metadata: memory.metadata,
        actor: memory.actor,
        project: memory.project,
        tags: memory.tags,
        parent_id: memory.parent_id,
        external_ref: memory.external_ref,
        severity: memory.severity
      }

      DiwaAgent.Cloud.SyncQueue.enqueue("memory", payload)
    else
      :ok
    end
  end

  defp spawn_embedding_task(memory, content) do
    # Check if TaskSupervisor is started (e.g. in test env it might not be)
    if Process.whereis(DiwaAgent.TaskSupervisor) do
      Task.Supervisor.start_child(DiwaAgent.TaskSupervisor, fn ->
        case @embedding_module.generate_embedding(content) do
          {:ok, vec} ->
            @vector_repo_module.upsert_embedding(memory.id, vec, %{})

          _ ->
            :ok
        end
      end)
    else
      :ok
    end
  end

  defp normalize_opts(opts) do
    case opts do
      m when is_map(m) ->
        m

      s when is_binary(s) ->
        case Jason.decode(s) do
          {:ok, decoded} when is_map(decoded) -> %{metadata: decoded}
          _ -> %{metadata: %{raw: s}}
        end

      nil ->
        %{metadata: %{}}
    end
  end

  defp normalize_tags(tags) do
    case tags do
      nil -> []
      t when is_list(t) -> t
      t when is_binary(t) -> String.split(t, ",") |> Enum.map(&String.trim/1)
    end
  end

  defp decode_safe(val) when is_binary(val), do: Jason.decode(val)
  defp decode_safe(val), do: {:ok, val}

  defp update_context_timestamp(context_id) do
    case Repo.get(Context, context_id) do
      nil ->
        :ok

      context ->
        context
        |> DiwaSchema.Core.Context.touch_changeset(%{updated_at: DateTime.utc_now()})
        |> Repo.update()
    end
  end
end

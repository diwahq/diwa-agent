defmodule DiwaAgent.Storage.MigrationTool do
  @moduledoc """
  Tool to migrate data from SQLite (v1) to PostgreSQL (v2).
  """

  alias DiwaAgent.Repo
  alias DiwaSchema.Enterprise.Organization
  alias DiwaSchema.Core.Context
  alias DiwaSchema.Core.Memory
  require Logger

  @doc """
  Runs the full migration from the given SQLite database path.
  """
  def run(sqlite_db_path) do
    Logger.info("[Migration] Starting migration from #{sqlite_db_path}")

    case Exqlite.Sqlite3.open(sqlite_db_path) do
      {:ok, conn} ->
        # 1. Ensure Default Organization exists
        default_org_id = ensure_default_org()

        # 2. Migrate Contexts
        contexts = fetch_sqlite_contexts(conn)
        Logger.info("[Migration] Found #{length(contexts)} contexts in SQLite")

        migrate_contexts(contexts, default_org_id)

        # 3. Migrate Memories
        memories = fetch_sqlite_memories(conn)
        Logger.info("[Migration] Found #{length(memories)} memories in SQLite")

        migrate_memories(memories)

        Exqlite.Sqlite3.close(conn)
        Logger.info("[Migration] Done!")
        :ok

      {:error, reason} ->
        Logger.error("[Migration] Failed to open SQLite DB: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp ensure_default_org do
    case Repo.get_by(Organization, name: "Default") do
      nil ->
        {:ok, org} =
          %Organization{} |> Organization.changeset(%{name: "Default"}) |> Repo.insert()

        org.id

      org ->
        org.id
    end
  end

  defp fetch_sqlite_contexts(conn) do
    sql = "SELECT id, name, description, created_at, updated_at FROM contexts"
    {:ok, statement} = Exqlite.Sqlite3.prepare(conn, sql)
    rows = fetch_all(conn, statement)
    Exqlite.Sqlite3.release(conn, statement)
    rows
  end

  defp fetch_sqlite_memories(conn) do
    sql =
      "SELECT id, context_id, content, metadata, actor, project, tags, parent_id, external_ref, severity, created_at, updated_at FROM memories"

    {:ok, statement} = Exqlite.Sqlite3.prepare(conn, sql)
    rows = fetch_all(conn, statement)
    Exqlite.Sqlite3.release(conn, statement)
    rows
  end

  defp fetch_all(conn, statement, acc \\ []) do
    case Exqlite.Sqlite3.step(conn, statement) do
      {:row, row} -> fetch_all(conn, statement, [row | acc])
      :done -> Enum.reverse(acc)
    end
  end

  defp migrate_contexts(rows, org_id) do
    Enum.each(rows, fn [id, name, desc, created, updated] ->
      attrs = %{
        id: id,
        name: name,
        description: desc,
        organization_id: org_id,
        inserted_at: parse_iso8601(created),
        updated_at: parse_iso8601(updated)
      }

      case Repo.get(Context, id) do
        nil -> %Context{} |> Context.changeset(attrs) |> Repo.insert()
        # Skip existing
        _ -> :ok
      end
    end)
  end

  defp migrate_memories(rows) do
    Enum.each(rows, fn [
                         id,
                         cid,
                         content,
                         meta,
                         actor,
                         proj,
                         tags,
                         pid,
                         eref,
                         sev,
                         created,
                         updated
                       ] ->
      metadata =
        case meta do
          nil ->
            %{}

          s ->
            case Jason.decode(s) do
              {:ok, d} -> d
              _ -> %{raw: s}
            end
        end

      tag_list =
        case tags do
          nil -> []
          t -> String.split(t, ",") |> Enum.map(&String.trim/1)
        end

      attrs = %{
        id: id,
        context_id: cid,
        content: content,
        metadata: metadata,
        actor: actor,
        project: proj,
        tags: tag_list,
        parent_id: pid,
        external_ref: eref,
        severity: sev,
        inserted_at: parse_iso8601(created),
        updated_at: parse_iso8601(updated)
      }

      case Repo.get(Memory, id) do
        nil -> %Memory{} |> Memory.changeset(attrs) |> Repo.insert()
        _ -> :ok
      end
    end)
  end

  defp parse_iso8601(nil), do: DateTime.utc_now()

  defp parse_iso8601(string) do
    case DateTime.from_iso8601(string) do
      {:ok, dt, _offset} -> dt
      _ -> DateTime.utc_now()
    end
  end
end

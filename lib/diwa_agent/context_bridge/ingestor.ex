defmodule DiwaAgent.ContextBridge.Ingestor do
  @moduledoc """
  Advanced Project Context Ingestor.
  Scans project directories (.agent, .cursor, etc.), classifies files, 
  and persists them as memories. Tracks progress via IngestJobs.
  """

  alias DiwaAgent.Repo
  alias DiwaAgent.Storage.Schemas.{IngestJob, Memory}
  alias DiwaAgent.ContextBridge.MemoryClassification
  require Logger

  @default_dirs [".agent", ".cursor"]

  @doc """
  Runs an ingestion job for a context.
  """
  def run(context_id, opts \\ []) do
    dirs = opts[:dirs] || @default_dirs

    {:ok, job} = create_job(context_id, opts)

    try do
      results =
        dirs
        |> Enum.flat_map(fn dir -> scan_directory(dir) end)
        |> Enum.map(fn file_path -> ingest_file(context_id, file_path) end)

      stats = summarize(results)
      update_job(job, %{status: "completed", stats: stats})
      {:ok, stats}
    rescue
      e ->
        Logger.error("Ingest failed: #{inspect(e)}")
        update_job(job, %{status: "failed", metadata: %{error: inspect(e)}})
        {:error, e}
    end
  end

  defp create_job(context_id, opts) do
    attrs = %{
      context_id: context_id,
      status: "running",
      source_type: opts[:source_type] || "filesystem",
      source_path: opts[:source_path] || ".",
      stats: %{started_at: DateTime.utc_now()}
    }

    %IngestJob{}
    |> IngestJob.changeset(attrs)
    |> Repo.insert()
  end

  defp update_job(job, attrs) do
    job
    |> IngestJob.changeset(attrs)
    |> Repo.update()
  end

  defp scan_directory(dir) do
    if File.dir?(dir) do
      File.ls!(dir)
      |> Enum.map(fn f -> Path.join(dir, f) end)
      |> Enum.filter(fn path -> !File.dir?(path) && String.ends_with?(path, ".md") end)
    else
      []
    end
  end

  defp ingest_file(context_id, path) do
    content = File.read!(path)
    filename = Path.basename(path)

    # Module 2 Integration: Automated Classification
    {:ok, class, priority, lifecycle} = MemoryClassification.classify(content, filename: filename)

    # Simple deduplication check: skip if content already exists in this context
    # In a real system, we'd use semantic fingerprints or hashes
    case find_duplicate(context_id, content) do
      nil ->
        attrs = %{
          context_id: context_id,
          content: content,
          actor: "Ingestor/v2",
          source: path,
          memory_class: Atom.to_string(class),
          priority: Atom.to_string(priority),
          lifecycle: Atom.to_string(lifecycle),
          tags: ["ingested", Path.dirname(path)],
          metadata: %{
            "original_path" => path,
            "filename" => filename
          }
        }

        case %Memory{} |> Memory.changeset(attrs) |> Repo.insert() do
          {:ok, _} -> {:ok, :created, path}
          {:error, _} -> {:error, :failed, path}
        end

      _existing ->
        {:ok, :skipped, path}
    end
  end

  defp find_duplicate(context_id, content) do
    import Ecto.Query

    query =
      from(m in Memory,
        where: m.context_id == ^context_id and m.content == ^content,
        limit: 1
      )

    Repo.one(query)
  end

  defp summarize(results) do
    results
    |> Enum.reduce(%{created: 0, skipped: 0, failed: 0}, fn
      {:ok, :created, _}, acc -> %{acc | created: acc.created + 1}
      {:ok, :skipped, _}, acc -> %{acc | skipped: acc.skipped + 1}
      {:error, :failed, _}, acc -> %{acc | failed: acc.failed + 1}
    end)
  end
end

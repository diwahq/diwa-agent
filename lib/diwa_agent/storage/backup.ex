defmodule DiwaAgent.Storage.Backup do
  @moduledoc """
  Enterprise Backup & Data Portability logic.

  Handles automated JSON exports of contexts to ensure data safety.
  """

  alias DiwaAgent.Storage.{Context, Memory}
  require Logger

  @backup_dir Path.expand("~/.diwa/backups")

  @doc """
  Performs a full backup of all contexts.
  """
  def perform_full_backup do
    try do
      File.mkdir_p!(@backup_dir)
      Logger.info("[Backup] Starting full system backup to #{@backup_dir}")

      {:ok, contexts} = Context.list()

      results =
        Enum.map(contexts, fn ctx ->
          backup_context(ctx.id)
        end)

      success_count =
        Enum.count(results, fn
          {:ok, _} -> true
          _ -> false
        end)

      Logger.info(
        "[Backup] Full backup complete. #{success_count}/#{length(contexts)} contexts backed up."
      )

      {:ok, success_count}
    rescue
      e ->
        Logger.error("[Backup] Full backup failed: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc """
  Backs up a specific context to a JSON file.
  """
  def backup_context(context_id) do
    with {:ok, context} <- Context.get(context_id),
         {:ok, memories} <- Memory.list(context_id, limit: 10000) do
      filename =
        "#{context.name |> String.downcase() |> String.replace(" ", "_")}_#{DateTime.utc_now() |> DateTime.to_unix()}.json"

      path = Path.join(@backup_dir, filename)

      export_data = %{
        version: "2.0",
        exported_at: DateTime.utc_now(),
        context: context,
        memories: memories
      }

      File.write!(path, Jason.encode!(export_data, pretty: true))
      Logger.info("[Backup] Context '#{context.name}' backed up to #{path}")
      {:ok, path}
    else
      error ->
        Logger.error("[Backup] Failed to backup context #{context_id}: #{inspect(error)}")
        error
    end
  end
end

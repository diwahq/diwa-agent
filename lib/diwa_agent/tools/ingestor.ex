defmodule DiwaAgent.Tools.Ingestor do
  @moduledoc """
  Tool for ingesting project-specific AI context from local files (like .agent directory).
  """
  alias DiwaAgent.Storage.Memory
  require Logger

  @agent_dir ".agent"

  @doc """
  Ingests all markdown files from the .agent directory into the specified context.
  """
  def ingest(context_id) do
    if File.dir?(@agent_dir) do
      files =
        @agent_dir
        |> File.ls!()
        |> Enum.filter(&String.ends_with?(&1, ".md"))

      results =
        Enum.map(files, fn filename ->
          path = Path.join(@agent_dir, filename)
          content = File.read!(path)

          # Use filename (without extension) as a tag
          base_name = Path.rootname(filename)
          tags = [base_name, "agent-context", "ingested"]

          metadata = %{
            "source" => "local_file",
            "filename" => filename,
            "ingested_at" => DateTime.utc_now() |> DateTime.to_iso8601()
          }

          msg = "Ingesting #{filename}..."
          Logger.info(msg)

          case Memory.add(context_id, content, %{metadata: metadata, tags: tags}) do
            {:ok, _memory} -> {:ok, filename}
            {:error, reason} -> {:error, {filename, reason}}
          end
        end)

      successful = Enum.filter(results, &match?({:ok, _}, &1)) |> length()
      failed = Enum.filter(results, &match?({:error, _}, &1))

      summary = """
      ✓ Ingested #{successful} files from .agent directory.
      #{if length(failed) > 0, do: "❌ Failed: #{length(failed)} files.\n" <> format_errors(failed), else: ""}
      """

      {:ok, summary}
    else
      {:error, "Directory .agent not found in current project root."}
    end
  end

  defp format_errors(errors) do
    errors
    |> Enum.map(fn {:error, {file, reason}} -> "  - #{file}: #{inspect(reason)}" end)
    |> Enum.join("\n")
  end
end

defmodule Mix.Tasks.Diwa.Export do
  use Mix.Task
  require Logger
  alias DiwaAgent.Repo
  alias DiwaSchema.Core.{Context, Memory, ContextBinding, ContextRelationship}
  alias DiwaSchema.Enterprise.Organization
  import Ecto.Query

  @shortdoc "Export all Diwa data to JSON"

  @fields_to_drop [
    :__meta__,
    :context,
    :source_context,
    :target_context,
    :organization,
    :memories,
    :bindings,
    :children,
    :parent_memory,
    :versions,
    :embedding
  ]

  def run(args) do
    # Start the application to ensure Repo is available
    {:ok, _} = Application.ensure_all_started(:diwa_agent)

    {opts, _} = OptionParser.parse!(args, strict: [output: :string, format: :string])
    output_path = Keyword.get(opts, :output, "diwa_export.json")

    IO.puts("🚀 Starting Diwa Agent Export...")
    IO.puts("   Output: #{output_path}")

    data = %{
      "version" => "1.0",
      "exported_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "source" => "diwa-agent",
      "source_version" => "1.0.0",
      "organizations" => export_table(Organization),
      "contexts" => export_table(Context),
      "memories" => export_table(Memory),
      "bindings" => export_table(ContextBinding),
      "relationships" => export_table(ContextRelationship)
    }

    IO.puts("   - Contexts: #{length(data["contexts"])}")
    IO.puts("   - Memories: #{length(data["memories"])}")
    IO.puts("   - Bindings: #{length(data["bindings"])}")
    IO.puts("   - Relationships: #{length(data["relationships"])}")

    case Jason.encode(data, pretty: true) do
      {:ok, json} ->
        File.write!(output_path, json)
        IO.puts("\n✅ Export complete! Saved to #{output_path}")

      {:error, reason} ->
        IO.puts("\n❌ Export failed: #{inspect(reason)}")
    end
  end

  defp export_table(schema) do
    Repo.all(schema)
    |> Enum.map(&Map.from_struct/1)
    |> Enum.map(&sanitize_map/1)
  end

  defp sanitize_map(map) do
    map
    |> Map.drop(@fields_to_drop)
    |> Enum.reduce(%{}, fn
      {k, %Ecto.Association.NotLoaded{}}, acc -> acc
      {k, v}, acc when is_struct(v, DateTime) -> Map.put(acc, k, DateTime.to_iso8601(v))
      {k, v}, acc when is_struct(v, NaiveDateTime) -> Map.put(acc, k, NaiveDateTime.to_iso8601(v))
      {k, v}, acc -> Map.put(acc, k, v)
    end)
  end
end

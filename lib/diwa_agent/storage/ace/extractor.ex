defmodule DiwaAgent.Storage.ACE.Extractor do
  @moduledoc """
  Core engine for Auto-Context Extraction (Patent #2).

  Coordinates scanners to build a map of the project's architecture
  and persists them as memories in a context.
  """

  @scanners [DiwaAgent.Storage.ACE.Scanners.Elixir]
  alias DiwaAgent.Storage.Memory
  require Logger

  @doc """
  Runs ACE on a directory path and saves results to a context.
  """
  def extract(context_id, path) do
    Logger.info("[ACE] Starting automated extraction from #{path}")

    # 1. Ensure path exists
    unless File.dir?(path) do
      {:error, :invalid_path}
    else
      # 2. Run all scanners
      results =
        Enum.flat_map(@scanners, fn scanner ->
          case scanner.scan(path) do
            {:ok, facts} -> facts
            _ -> []
          end
        end)

      # 3. Persist facts as Memories
      # We use tags to mark them as system-extracted
      Enum.each(results, fn fact ->
        opts = %{
          metadata:
            Jason.encode!(%{
              type: "ace_fact",
              fact_type: Atom.to_string(fact.type),
              source_path: path,
              extraction_date: DateTime.utc_now()
            }),
          actor: "ACE_Engine",
          tags: fact.tags ++ ["ace", "auto_generated"]
        }

        content = "### [ACE] #{fact.name}\n\n#{fact.content}"

        # Avoid duplicates by checking if fact already exists in this context
        # Simplified: just add it for now
        Memory.add(context_id, content, opts)
      end)

      {:ok, %{extracted_facts: length(results)}}
    end
  end
end

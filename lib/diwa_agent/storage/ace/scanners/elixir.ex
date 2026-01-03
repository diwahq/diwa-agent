defmodule DiwaAgent.Storage.ACE.Scanners.Elixir do
  @moduledoc """
  ACE Scanner for Elixir projects.

  Extracts architectural metadata from mix.exs and modular structures.
  """

  @behaviour DiwaAgent.Storage.ACE.Scanner
  require Logger

  @impl true
  def scan(root_path) do
    Logger.info("[ACE] Scanning Elixir project at #{root_path}")

    with {:ok, deps} <- scan_dependencies(root_path),
         {:ok, modules} <- scan_modules(root_path) do
      {:ok, deps ++ modules}
    else
      error -> error
    end
  end

  defp scan_dependencies(root_path) do
    mix_path = Path.join(root_path, "mix.exs")

    if File.exists?(mix_path) do
      content = File.read!(mix_path)
      # Simple regex-based dependency extraction for Phase 1
      # In Phase 2 we would use code analysis
      deps =
        Regex.scan(~r/{:(\w+),/, content)
        |> Enum.map(fn [_, name] ->
          %{
            type: :dependency,
            name: name,
            content: "Project depends on #{name}",
            metadata: %{source: "mix.exs"},
            tags: ["elixir", "dependency"]
          }
        end)

      {:ok, deps}
    else
      {:ok, []}
    end
  end

  defp scan_modules(root_path) do
    lib_path = Path.join(root_path, "lib")

    if File.dir?(lib_path) do
      facts =
        Path.wildcard("#{lib_path}/**/*.ex")
        |> Enum.flat_map(fn file_path ->
          extract_module_facts(file_path)
        end)

      {:ok, facts}
    else
      {:ok, []}
    end
  end

  defp extract_module_facts(file_path) do
    content = File.read!(file_path)

    # Extract defmodule and @moduledoc
    module_name =
      case Regex.run(~r/defmodule\s+([\w\.]+)\s+do/, content) do
        [_, name] -> name
        _ -> nil
      end

    if module_name do
      moduledoc =
        case Regex.run(~r/@moduledoc\s+"""\s*(.*?)\s*"""/s, content) do
          [_, doc] -> String.trim(doc)
          _ -> "No documentation found for #{module_name}"
        end

      [
        %{
          type: :module,
          name: module_name,
          content: moduledoc,
          metadata: %{file: file_path},
          tags: ["elixir", "module", "architecture"]
        }
      ]
    else
      []
    end
  end
end

defmodule DiwaAgent.CodeBrowser do
  @moduledoc """
  Core engine for browsing and reading source code.
  Handles local filesystem access with safety checks.
  """

  require Logger

  @default_ignored ~w(node_modules _build deps .git .elixir_ls .vscode .idea .agent .cursor .gemini)

  @doc """
  Lists files and directories at a given path.
  """
  def list_files(root_path, relative_path \\ ".") do
    full_path = Path.expand(Path.join(root_path, relative_path))

    # Safety check: ensure the path is within the root_path
    if String.starts_with?(full_path, Path.expand(root_path)) do
      if File.dir?(full_path) do
        files =
          File.ls!(full_path)
          |> Enum.reject(&ignored?/1)
          |> Enum.map(fn name ->
            item_path = Path.join(full_path, name)

            %{
              name: name,
              type: if(File.dir?(item_path), do: :directory, else: :file),
              path: Path.relative_to(item_path, root_path)
            }
          end)
          |> Enum.sort_by(&{&1.type != :directory, &1.name})

        {:ok, files}
      else
        {:error, :not_a_directory}
      end
    else
      {:error, :access_denied}
    end
  end

  @doc """
  Reads the content of a file.
  """
  def read_file(root_path, relative_path, opts \\ []) do
    full_path = Path.expand(Path.join(root_path, relative_path))

    if String.starts_with?(full_path, Path.expand(root_path)) do
      case File.read(full_path) do
        {:ok, content} ->
          start_line = opts[:start_line]
          end_line = opts[:end_line]

          final_content =
            if start_line || end_line do
              extract_lines(content, start_line, end_line)
            else
              content
            end

          {:ok,
           %{
             path: relative_path,
             content: final_content,
             total_lines: line_count(content)
           }}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :access_denied}
    end
  end

  @doc """
  Performs a text search using ripgrep if available.
  """
  def search_code(root_path, query, opts \\ []) do
    # Check if rg is available
    case System.find_executable("rg") do
      nil ->
        {:error, :ripgrep_not_found}

      _rg_path ->
        args = ["--json", "--column", "--line-number", "--no-heading", "--smart-case"]

        args = if pattern = opts[:file_pattern], do: args ++ ["-g", pattern], else: args
        args = args ++ [query, root_path]

        case System.cmd("rg", args) do
          {output, 0} ->
            results = parse_rg_json(output, root_path)
            {:ok, results}

          {_output, 1} ->
            # No matches
            {:ok, []}

          {error, _} ->
            {:error, error}
        end
    end
  end

  # Helpers

  defp ignored?(name) do
    Enum.any?(@default_ignored, &(&1 == name))
  end

  defp line_count(content) do
    content |> String.split(["\n", "\r\n"]) |> Enum.count()
  end

  defp extract_lines(content, start_line, end_line) do
    lines = String.split(content, ["\n", "\r\n"])
    total = length(lines)

    start_idx = max(0, (start_line || 1) - 1)
    end_idx = min(total - 1, (end_line || total) - 1)

    lines
    |> Enum.slice(start_idx..end_idx)
    |> Enum.join("\n")
  end

  defp parse_rg_json(output, root_path) do
    output
    |> String.split("\n", trim: true)
    |> Enum.flat_map(fn line ->
      case Jason.decode(line) do
        {:ok, %{"type" => "match", "data" => data}} ->
          [
            %{
              path: Path.relative_to(data["path"]["text"], root_path),
              line: data["line_number"],
              column: data["submatches"] |> List.first() |> Map.get("start"),
              content: data["lines"]["text"] |> String.trim()
            }
          ]

        _ ->
          []
      end
    end)
  end
end

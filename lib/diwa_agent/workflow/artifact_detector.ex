defmodule DiwaAgent.Workflow.ArtifactDetector do
  @moduledoc """
  Pattern matching engine for automatic artifact detection.

  Detects specs, RFCs, and decisions from:
  - File patterns (headers, YAML frontmatter)
  - Verbal triggers in content
  - File locations
  - Explicit markers
  """

  require Logger

  @doc """
  Check if content should be queued as an artifact.

  Returns:
  - {:queue, type, metadata} if artifact detected
  - :ignore if not an artifact
  """
  def detect(content, opts \\ []) do
    path = Keyword.get(opts, :path)

    cond do
      # 1. Explicit marker
      has_handoff_marker?(content) ->
        detect_type_from_content(content, path)

      # 2. File patterns (headers)
      has_spec_header?(content) ->
        {:queue, :spec, extract_metadata(content, :spec)}

      has_rfc_header?(content) ->
        {:queue, :rfc, extract_metadata(content, :rfc)}

      has_decision_header?(content) ->
        {:queue, :decision, extract_metadata(content, :decision)}

      # 3. YAML frontmatter detection
      has_actor_coder?(content) ->
        {:queue, :spec, extract_metadata(content, :spec)}

      # 4. Location-based (outputs directory)
      is_output_file?(path) ->
        detect_type_from_content(content, path)

      # 5. Verbal triggers in content
      has_verbal_trigger?(content) ->
        {:queue, :note, extract_metadata(content, :note)}

      true ->
        :ignore
    end
  end

  @doc """
  Auto-detect artifacts from file write operations.
  Called when files are created in monitored locations.
  """
  def detect_from_file(path) do
    if File.exists?(path) do
      content = File.read!(path)
      detect(content, path: path)
    else
      :ignore
    end
  end

  ## Pattern Matchers

  defp has_handoff_marker?(content) do
    content =~ ~r/<!--\s*handoff\s*-->/i or
      content =~ ~r/\bhands?-?off\b/i
  end

  defp has_spec_header?(content) do
    content =~ ~r/^#+ Specification:/mi or
      content =~ ~r/^#+ Spec:/mi or
      content =~ ~r/^#.*\bSpec\b.*-.*$/mi
  end

  defp has_rfc_header?(content) do
    content =~ ~r/^#+ RFC:/mi or
      content =~ ~r/^#+ Request for Comment/mi
  end

  defp has_decision_header?(content) do
    content =~ ~r/^#+ DECISION:/mi or
      content =~ ~r/^#+ Decision:/mi
  end

  defp has_actor_coder?(content) do
    # YAML frontmatter pattern
    content =~ ~r/^---\n.*actor:\s*coder/ms or
      content =~ ~r/actor:\s*coder/i
  end

  defp is_output_file?(nil), do: false

  defp is_output_file?(path) do
    String.contains?(path, "/mnt/user-data/outputs/") or
      String.contains?(path, "outputs/") or
      String.ends_with?(path, "_spec.md")
  end

  defp has_verbal_trigger?(content) do
    triggers = [
      ~r/add this to (the )?handoff/i,
      ~r/include (this )?in (the )?handoff/i,
      ~r/spec (is )?ready/i,
      ~r/ready for handoff/i
    ]

    Enum.any?(triggers, &Regex.match?(&1, content))
  end

  ## Metadata Extraction

  defp extract_metadata(content, type) do
    %{
      title: extract_title(content, type),
      priority: extract_priority(content),
      repo: extract_repo(content),
      actor: extract_actor(content)
    }
  end

  defp extract_title(content, type) do
    cond do
      # Try markdown header
      title = extract_from_header(content) ->
        title

      # Try YAML frontmatter
      title = extract_from_yaml(content, "title") ->
        title

      # Default based on type
      true ->
        "#{Atom.to_string(type) |> String.capitalize()} Document"
    end
  end

  defp extract_from_header(content) do
    case Regex.run(~r/^#+\s*(.+?)$/m, content) do
      [_, title] ->
        # Clean up the title
        title
        |> String.replace(~r/^(Specification|Spec|RFC|Decision):\s*/i, "")
        |> String.trim()

      _ ->
        nil
    end
  end

  defp extract_from_yaml(content, key) do
    # Simple YAML extraction (not a full parser)
    regex = ~r/^#{key}:\s*(.+)$/m

    case Regex.run(regex, content) do
      [_, value] -> String.trim(value)
      _ -> nil
    end
  end

  defp extract_priority(content) do
    cond do
      content =~ ~r/priority:\s*(P0|Critical)/i -> "P0"
      content =~ ~r/priority:\s*P1/i -> "P1"
      content =~ ~r/priority:\s*P2/i -> "P2"
      true -> nil
    end
  end

  defp extract_repo(content) do
    case extract_from_yaml(content, "repo") do
      nil -> "unknown"
      repo -> repo
    end
  end

  defp extract_actor(content) do
    case extract_from_yaml(content, "actor") do
      nil -> "unknown"
      actor -> actor
    end
  end

  defp detect_type_from_content(content, path) do
    type =
      cond do
        has_spec_header?(content) -> :spec
        has_rfc_header?(content) -> :rfc
        has_decision_header?(content) -> :decision
        path && String.ends_with?(path, "_spec.md") -> :spec
        true -> :note
      end

    {:queue, type, extract_metadata(content, type)}
  end

  @doc """
  Scan a text message for queue commands.
  Returns {:queue, artifact} or :ignore
  """
  def scan_message(message) do
    cond do
      # Explicit queue command
      command = extract_queue_command(message) ->
        command

      # Detect artifact in message content
      detect(message) != :ignore ->
        detect(message)

      true ->
        :ignore
    end
  end

  defp extract_queue_command(message) do
    # Match: @queue "content" or @queue file.md
    case Regex.run(~r/@queue\s+"([^"]+)"/i, message) do
      [_, content] ->
        {:queue, :note, %{title: "Queued Note", content: content}}

      _ ->
        case Regex.run(~r/@queue\s+(\S+\.md)/i, message) do
          [_, path] -> {:queue_file, path}
          _ -> nil
        end
    end
  end
end

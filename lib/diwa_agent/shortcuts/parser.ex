defmodule DiwaAgent.Shortcuts.Parser do
  @moduledoc """
  Parses raw input strings into command tokens and extracts arguments.

  Example Input: `/bug "Login failed" "Error 500 on auth"`
  Output: `{:ok, "bug", ["Login failed", "Error 500 on auth"]}`
  """

  @doc """
  Tokenizes an input string into a command and a list of arguments.
  Supports quoted arguments for strings containing spaces.
  """
  def tokenize(input) when is_binary(input) do
    trimmed = String.trim(input)

    cond do
      trimmed == "" -> {:error, :empty_input}
      # Support both "/" and "@" as prefix for shortcuts
      String.starts_with?(trimmed, "/") -> do_tokenize(trimmed, "/")
      String.starts_with?(trimmed, "@") -> do_tokenize(trimmed, "@")
      true -> {:error, :missing_prefix}
    end
  end

  defp do_tokenize(input, prefix) do
    # Remove leading prefix length
    prefix_len = String.length(prefix)
    without_prefix = String.slice(input, prefix_len..-1//1)
    
    # Regex to capture command (first word) and then remainder
    case Regex.run(~r/^(\S+)(.*)$/s, without_prefix) do
      [_, command, rest] ->
        args = split_args(rest)
        {:ok, command, args}

      nil ->
        {:error, :invalid_format}
    end
  end

  # Splits arguments handling quoted strings
  # Simple regex simulation of shell splitting
  defp split_args(args_str) do
    # This regex matches:
    # 1. Quoted string: "..."
    # 2. Non-whitespace sequence: \S+
    ~r/"([^"]*)"|(\S+)/
    |> Regex.scan(args_str)
    |> Enum.map(fn
      # Match group 1 (quoted content)
      [_, quoted, ""] -> quoted
      # Match group 2 (simple word)
      [_, "", simple] -> simple
      # "quoted"
      [_match, quoted] -> quoted
      # Fallback (should normally hit above)
      [match] -> String.trim(match, "\"")
    end)
  end

  @doc """
  Maps positional arguments to a named map based on a schema.

  ## Examples
      iex> extract_args(["Title", "Desc"], [:title, :description])
      {:ok, %{"title" => "Title", "description" => "Desc"}}
  """
  def extract_args(args_list, param_names) when is_list(args_list) and is_list(param_names) do
    if length(args_list) > length(param_names) do
      {:error, :too_many_arguments}
    else
      # Zip matches positionals. Using Stream.zip to handle varying lengths safely? 
      # Actually Enum.zip stops at shortest.
      # But we want to ensure we have enough args if parameters are mandatory?
      # For now, we assume optional tail args are nil? Or strict arity?
      # Let's support partial application and default the rest to nil for now.

      mapped =
        Enum.zip(param_names, args_list)
        |> Enum.into(%{}, fn {k, v} -> {to_string(k), v} end)

      {:ok, mapped}
    end
  end
end

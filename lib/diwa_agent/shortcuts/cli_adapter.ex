defmodule DiwaAgent.Shortcuts.CLIAdapter do
  @moduledoc """
  Adapter for CLI interaction with the Shortcut Interpreter.
  Handles formatting of output for terminal usage.
  """
  require Logger
  alias DiwaAgent.Shortcuts.Interpreter

  def run(input_string, context_id) do
    Logger.info("CLI Shortcut: #{input_string} [Context: #{context_id}]")

    case Interpreter.process(input_string, context_id) do
      {:ok, result} ->
        format_success(result)

      {:error, reason} ->
        format_error(reason)
    end
  end

  defp format_success(result) do
    # Try to extract text if it's an MCP response map
    text =
      case result do
        %{content: [%{text: t} | _]} -> t
        %{"content" => [%{"text" => t} | _]} -> t
        other -> inspect(other, pretty: true)
      end

    IO.puts("\n✅ SUCCESS:\n")
    IO.puts(text)
    :ok
  end

  defp format_error(reason) do
    IO.puts("\n❌ ERROR:\n")
    IO.puts(inspect(reason))
    :error
  end
end

defmodule DiwaAgent.Shortcuts.Interpreter do
  @moduledoc """
  Main entry point for processing shortcuts.
  Coordinates parsing, resolution, and execution.
  """
  alias DiwaAgent.Shortcuts.{Parser, Registry}
  require Logger

  @doc """
  Processes a raw shortcut input string.

  ## Example
      Interpreter.process("/bug 'Login failed' '500 error'", "ctx-123")

  ## Returns
  - `{:ok, result}`: Tool execution result
  - `{:error, reason}`: Parsing or execution error
  """
  def process(input_string, context_id, executor_mod \\ DiwaAgent.Shortcuts.Executor) do
    with {:ok, command, args} <- Parser.tokenize(input_string),
         {:ok, definition} <- Registry.resolve(command) do
      result = executor_mod.execute(definition, args, context_id)

      # If deprecated, prepend a warning to the response
      if Map.get(definition, :deprecated, false) do
        add_deprecation_warning(result, command, definition.tool)
      else
        result
      end
    else
      {:error, :not_found} ->
        Logger.warning("Shortcut not found for input: #{String.slice(input_string, 0, 20)}...")
        {:error, "Unknown shortcut command."}

      {:error, reason} ->
        Logger.error("Shortcut error: #{inspect(reason)}")
        {:error, "Shortcut failed: #{inspect(reason)}"}
    end
  end

  def interpret(input_string, context_id) do
    process(input_string, context_id)
  end

  defp add_deprecation_warning(%{"content" => [%{"text" => text} | rest]} = resp, command, tool) do
    warning = "⚠️  Shortcut @#{command} is DEPRECATED. Please use @#{tool} instead.\n\n"

    Map.put(resp, "content", [%{"type" => "text", "text" => warning <> text} | rest])
  end

  defp add_deprecation_warning(other, _command, _tool), do: other
end

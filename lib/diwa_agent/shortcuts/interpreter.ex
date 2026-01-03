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
      
      executor_mod.execute(definition, args, context_id)
    else
      {:error, :not_found} -> 
        Logger.warning("Shortcut not found for input: #{String.slice(input_string, 0, 20)}...")
        {:error, "Unknown shortcut command."}
        
      {:error, reason} -> 
        Logger.error("Shortcut error: #{inspect(reason)}")
        {:error, "Shortcut failed: #{inspect(reason)}"}
    end
  end
end

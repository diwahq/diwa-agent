defmodule DiwaAgent.Shortcuts.Executor do
  @moduledoc """
  Executes a resolved shortcut definition by mapping arguments and invoking the target MCP tool.
  """
  require Logger

  @doc """
  Executes a shortcut.

  ## Parameters
  - definition: The shortcut map `%{tool: "name", schema: [...], ...}`
  - args_list: List of positional arguments `["arg1", "arg2"]`
  - context_id: Current context ID

  ## Returns
  - `{:ok, result}` from the tool
  - `{:error, reason}`
  """
  def execute(definition, args_list, context_id, executor_mod \\ DiwaAgent.Tools.Executor) do
    with {:ok, args_map} <- map_arguments(definition, args_list, context_id) do
      # Add context_id implicitly if not present, as most tools need it
      final_args = Map.put_new(args_map, "context_id", context_id)

      Logger.info("Executing shortcut tool: #{definition.tool} args: #{inspect(final_args)}")
      executor_mod.execute(definition.tool, final_args)
    end
  end

  defp map_arguments(definition, args_list, _context_id) do
    # Use Parser.extract_args logic (or direct mapping if simple)
    # We should probably reuse the Parser logic here or move it.
    # Since Parser is "Parser", let's use it.
    DiwaAgent.Shortcuts.Parser.extract_args(args_list, definition.schema)
  end
end

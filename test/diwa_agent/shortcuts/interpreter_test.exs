defmodule DiwaAgent.Shortcuts.InterpreterTest do
  use ExUnit.Case, async: true
  alias DiwaAgent.Shortcuts.Interpreter

  # We can't easily test side effects without a real MCP integration or better mocking.
  # But we can test parsing -> resolution flow for built-ins.

  defmodule FakeShortcutExecutor do
    def execute(definition, _args, _ctx_id) do
      {:ok, "Executed #{definition.tool}"}
    end
  end

  test "processes a known shortcut (plan)" do
    context_id = "ctx-123"
    result = Interpreter.process("/plan", context_id, FakeShortcutExecutor)

    assert {:ok, "Executed get_project_status"} = result
  end

  test "returns error for unknown shortcut" do
    assert {:error, "Unknown shortcut command."} = Interpreter.process("/invalid_stuff", "ctx-1")
  end
end

defmodule DiwaAgent.Shortcuts.ExecutorTest do
  use ExUnit.Case, async: true
  alias DiwaAgent.Shortcuts.Executor

  defmodule FakeExecutor do
    def execute(tool, args) do
      {:ok, {tool, args}}
    end
  end

  describe "execute/4" do
    test "maps arguments and calls injected executor" do
      definition = %{tool: "log_progress", schema: [:message]}
      args = ["Doing work"]
      context_id = "ctx-123"

      assert {:ok, {"log_progress", called_args}} =
               Executor.execute(definition, args, context_id, FakeExecutor)

      assert called_args["message"] == "Doing work"
      assert called_args["context_id"] == "ctx-123"
    end

    test "fails if argument mapping fails" do
      definition = %{tool: "log_progress", schema: [:message]}
      # Too many args for schema
      args = ["Doing work", "Too many"]
      context_id = "ctx-123"

      assert {:error, :too_many_arguments} = Executor.execute(definition, args, context_id)
    end
  end
end

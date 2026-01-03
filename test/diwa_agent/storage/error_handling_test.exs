defmodule DiwaAgent.Storage.ErrorHandlingTest do
  use ExUnit.Case, async: false
  alias DiwaAgent.Storage.{Context, Memory}
  import DiwaAgent.TestHelper

  setup do
    db_path = setup_test_db()
    start_database()
    on_exit(fn -> cleanup_test_db(db_path) end)

    {:ok, context} = Context.create("Error Handling Context", "For edge cases")
    {:ok, context: context}
  end

  describe "Memory.add/3 edge cases" do
    test "returns error with invalid JSON metadata in options map", %{context: context} do
      # If passed as a direct string argument, it gracefully handles it (code reading confirmed).
      # But if passed inside a map: %{metadata: "invalid"}
      opts = %{metadata: "{invalid_json"}

      # We assume we want this to be safe
      result = Memory.add(context.id, "Content", opts)
      assert {:error, :invalid_metadata} = result
    end

    test "handles nil context_id gracefully" do
      result = Memory.add(nil, "Content", nil)
      assert {:error, :context_not_found} = result
    end
  end

  describe "Memory.update_metadata/2 edge cases" do
    test "returns error with invalid JSON string", %{context: context} do
      {:ok, mem} = Memory.add(context.id, "Test", nil)

      # Currently raises Jason.DecodeError, we want {:error, :invalid_metadata}
      result = Memory.update_metadata(mem.id, "{bad json")
      assert {:error, :invalid_metadata} = result
    end
  end
end

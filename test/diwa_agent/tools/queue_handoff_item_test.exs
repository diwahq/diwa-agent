defmodule DiwaAgent.Tools.QueueHandoffItemTest do
  use ExUnit.Case, async: false
  alias DiwaAgent.Tools.Executor
  alias DiwaAgent.Storage.{Context, Memory}
  import DiwaAgent.TestHelper

  setup do
    db_path = setup_test_db()
    start_database()
    on_exit(fn -> cleanup_test_db(db_path) end)
    
    {:ok, ctx} = Context.create("Handoff Test", "Testing @note")
    {:ok, context: ctx}
  end

  describe "queue_handoff_item tool" do
    test "queues a basic item", %{context: ctx} do
      result = Executor.execute("queue_handoff_item", %{
        "context_id" => ctx.id,
        "message" => "Finished API spec"
      })
      
      response = get_in(result, ["content", Access.at(0), "text"])
      assert response =~ "✓ Handoff item queued"
      
      # Verify memory created
      {:ok, [memory]} = Memory.list(ctx.id)
      assert memory.content =~ "[ACCOMPLISHMENT] Finished API spec"
      assert "handoff_item" in memory.tags
      assert "accomplishment" in memory.tags
    end
    
    test "queues item with custom category", %{context: ctx} do
      result = Executor.execute("queue_handoff_item", %{
        "context_id" => ctx.id,
        "message" => "Need database migrations",
        "category" => "next_step"
      })
      
      {:ok, [memory]} = Memory.list(ctx.id)
      assert memory.content =~ "[NEXT_STEP] Need database migrations"
      assert "next_step" in memory.tags
    end
    
    test "handles 'this' contextual extraction (no previous progress)", %{context: ctx} do
      result = Executor.execute("queue_handoff_item", %{
        "context_id" => ctx.id,
        "message" => "this"
      })
      
      {:ok, [memory]} = Memory.list(ctx.id)
      assert memory.content =~ "[AUTO] Captured contextual session state"
      assert "contextual" in memory.tags
    end
    
    test "handles 'this' with previous progress", %{context: ctx} do
      # Setup previous progress
      Memory.add(ctx.id, "Working on module X", %{tags: ["progress"]})
      
      result = Executor.execute("queue_handoff_item", %{
        "context_id" => ctx.id,
        "message" => "this"
      })
      
      # Should find the progress memory
      {:ok, list} = Memory.list(ctx.id)
      # list is desc order, so auto item is first
      auto_item = Enum.find(list, fn m -> "contextual" in m.tags end)
      
      assert auto_item.content =~ "[AUTO] Worked on: Working on module X"
    end
  end
end

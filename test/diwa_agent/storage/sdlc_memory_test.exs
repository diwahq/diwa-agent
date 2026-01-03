defmodule DiwaAgent.Storage.SDLCMemoryTest do
  use ExUnit.Case, async: false
  alias DiwaAgent.Storage.{Context, Memory}
  import DiwaAgent.TestHelper

  setup do
    db_path = setup_test_db()
    start_database()

    {:ok, context} = Context.create("SDLC Test", "Metadata testing")
    on_exit(fn -> cleanup_test_db(db_path) end)

    {:ok, context: context}
  end

  describe "SDLC fields support" do
    test "stores and retrieves all new SDLC fields", %{context: context} do
      opts = %{
        actor: "claudette",
        project: "KODA-V3",
        tags: "test,sdlc",
        external_ref: "https://github.com/issue/1",
        severity: "high",
        metadata: ~s({"extra": "data"})
      }

      assert {:ok, memory} = Memory.add(context.id, "SDLC Content", opts)

      assert memory.actor == "claudette"
      assert memory.project == "KODA-V3"
      assert memory.tags == ["test", "sdlc"]
      assert memory.external_ref == "https://github.com/issue/1"
      assert memory.severity == "high"
      assert memory.metadata == %{"extra" => "data"}

      # Verify retrieval
      assert {:ok, retrieved} = Memory.get(memory.id)
      assert retrieved.actor == "claudette"
      assert retrieved.tags == ["test", "sdlc"]
    end

    test "supports parent/child hierarchy", %{context: context} do
      {:ok, parent} = Memory.add(context.id, "Parent Memory", %{tags: "root"})
      {:ok, child} = Memory.add(context.id, "Child Memory", %{})

      assert {:ok, _} = Memory.set_parent(child.id, parent.id)

      {:ok, updated_child} = Memory.get(child.id)
      assert updated_child.parent_id == parent.id

      {:ok, children} = Memory.get_children(parent.id)
      assert length(children) == 1
      assert hd(children).id == child.id
    end

    test "list_by_tag filters correctly", %{context: context} do
      Memory.add(context.id, "Found", %{tags: "urgent,bug"})
      Memory.add(context.id, "Not found", %{tags: "feature"})

      assert {:ok, results} = Memory.list_by_tag(context.id, "urgent")
      assert length(results) == 1
      assert hd(results).content == "Found"
    end

    test "list_by_type (metadata search) still works", %{context: context} do
      Memory.add(context.id, "Type A", %{metadata: ~s({"type": "requirement"})})
      Memory.add(context.id, "Type B", %{metadata: ~s({"type": "other"})})

      assert {:ok, results} = Memory.list_by_type(context.id, "requirement")
      assert length(results) == 1
      assert hd(results).content == "Type A"
    end
  end

  describe "metadata updates" do
    test "updates only metadata and updated_at", %{context: context} do
      {:ok, memory} = Memory.add(context.id, "Content", %{metadata: ~s({"v": 1})})
      # Reload to sync precision
      {:ok, memory} = Memory.get(memory.id)
      orig_inserted_at = memory.inserted_at

      :timer.sleep(10)
      assert {:ok, updated} = Memory.update_metadata(memory.id, %{"v" => 2})

      assert updated.metadata == %{"v" => 2}
      assert updated.content == "Content"
      assert updated.inserted_at == orig_inserted_at
      assert updated.updated_at > memory.updated_at
    end
  end
end

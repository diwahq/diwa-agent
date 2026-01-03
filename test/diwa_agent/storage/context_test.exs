defmodule DiwaAgent.Storage.ContextTest do
  use ExUnit.Case, async: false
  alias DiwaAgent.Storage.Context
  import DiwaAgent.TestHelper

  setup do
    #  Setup test database
    db_path = setup_test_db()
    start_database()

    on_exit(fn -> cleanup_test_db(db_path) end)

    :ok
  end

  describe "create/2" do
    test "creates a context with valid data" do
      assert {:ok, context} = Context.create("Test Project", "A test project")

      assert context.id != nil
      assert context.name == "Test Project"
      assert context.description == "A test project"
      assert context.inserted_at != nil
      assert context.updated_at != nil
      assert context.inserted_at == context.updated_at
    end

    test "creates a context without description" do
      assert {:ok, context} = Context.create("Minimal Project", nil)

      assert context.name == "Minimal Project"
      assert context.description == nil
    end

    test "generates unique IDs for different contexts" do
      {:ok, context1} = Context.create("Project 1", nil)
      {:ok, context2} = Context.create("Project 2", nil)

      assert context1.id != context2.id
    end

    test "returns error with empty name" do
      assert {:error, _reason} = Context.create("", "description")
    end

    test "returns error with nil name" do
      assert {:error, _reason} = Context.create(nil, "description")
    end
  end

  describe "list/0" do
    test "returns empty list when no contexts exist" do
      assert {:ok, []} = Context.list()
    end

    test "returns all contexts ordered by creation time" do
      {:ok, ctx1} = Context.create("First", "First context")
      # Ensure different timestamps
      :timer.sleep(10)
      {:ok, ctx2} = Context.create("Second", "Second context")
      :timer.sleep(10)
      {:ok, ctx3} = Context.create("Third", "Third context")

      assert {:ok, contexts} = Context.list()
      assert length(contexts) == 3

      # Should be ordered by inserted_at (oldest first)
      assert Enum.at(contexts, 0).id == ctx1.id
      assert Enum.at(contexts, 1).id == ctx2.id
      assert Enum.at(contexts, 2).id == ctx3.id
    end

    test "returns contexts with all fields populated" do
      {:ok, _} = Context.create("Test", "Description")

      assert {:ok, [context]} = Context.list()
      assert context.id != nil
      assert context.name == "Test"
      assert context.description == "Description"
      assert context.inserted_at != nil
      assert context.updated_at != nil
    end
  end

  describe "get/1" do
    test "retrieves existing context by ID" do
      {:ok, created} = Context.create("Test Context", "Test description")

      assert {:ok, retrieved} = Context.get(created.id)
      assert retrieved.id == created.id
      assert retrieved.name == created.name
      assert retrieved.description == created.description
    end

    test "returns error for non-existent context" do
      fake_id = "00000000-0000-0000-0000-000000000000"
      assert {:error, :not_found} = Context.get(fake_id)
    end

    test "raises error for invalid UUID format" do
      assert_raise Ecto.Query.CastError, fn ->
        Context.get("not-a-uuid")
      end
    end

    test "returns error for nil ID" do
      assert {:error, :not_found} = Context.get(nil)
    end
  end

  describe "update/2" do
    test "updates context name" do
      {:ok, context} = Context.create("Old Name", "Description")
      original_updated_at = context.updated_at

      # Ensure timestamp changes
      :timer.sleep(10)

      assert {:ok, updated} = Context.update(context.id, %{name: "New Name"})
      assert updated.name == "New Name"
      assert updated.description == "Description"
      assert updated.updated_at > original_updated_at
    end

    test "updates context description" do
      {:ok, context} = Context.create("Name", "Old Description")

      assert {:ok, updated} = Context.update(context.id, %{description: "New Description"})
      assert updated.name == "Name"
      assert updated.description == "New Description"
    end

    test "updates both name and description" do
      {:ok, context} = Context.create("Old Name", "Old Description")

      assert {:ok, updated} =
               Context.update(context.id, %{
                 name: "New Name",
                 description: "New Description"
               })

      assert updated.name == "New Name"
      assert updated.description == "New Description"
    end

    test "returns error for non-existent context" do
      fake_id = "00000000-0000-0000-0000-000000000000"
      assert {:error, :not_found} = Context.update(fake_id, %{name: "New Name"})
    end

    test "preserves inserted_at timestamp" do
      {:ok, context} = Context.create("Name", "Description")
      # Reload to ensure DB precision matches
      {:ok, context} = Context.get(context.id)

      {:ok, updated} = Context.update(context.id, %{name: "New Name"})

      assert updated.inserted_at == context.inserted_at
    end
  end

  describe "delete/1" do
    test "deletes existing context" do
      {:ok, context} = Context.create("To Delete", "Will be deleted")

      assert :ok = Context.delete(context.id)
      assert {:error, :not_found} = Context.get(context.id)
    end

    test "returns error when deleting non-existent context" do
      fake_id = "00000000-0000-0000-0000-000000000000"
      assert {:error, :not_found} = Context.delete(fake_id)
    end

    test "removes context from list" do
      {:ok, ctx1} = Context.create("Keep", "Keep this")
      {:ok, ctx2} = Context.create("Delete", "Delete this")

      :ok = Context.delete(ctx2.id)

      assert {:ok, contexts} = Context.list()
      assert length(contexts) == 1
      assert hd(contexts).id == ctx1.id
    end
  end

  describe "count/0" do
    test "returns 0 when no contexts exist" do
      assert {:ok, 0} = Context.count()
    end

    test "returns correct count" do
      Context.create("One", nil)
      Context.create("Two", nil)
      Context.create("Three", nil)

      assert {:ok, 3} = Context.count()
    end

    test "count decreases after deletion" do
      {:ok, ctx} = Context.create("Delete Me", nil)
      assert {:ok, 1} = Context.count()

      Context.delete(ctx.id)
      assert {:ok, 0} = Context.count()
    end
  end

  describe "edge cases" do
    test "handles long names within limits" do
      long_name = String.duplicate("A", 250)
      assert {:ok, context} = Context.create(long_name, nil)
      assert context.name == long_name
    end

    test "handles very long descriptions" do
      long_desc = String.duplicate("B", 10000)
      assert {:ok, context} = Context.create("Name", long_desc)
      assert context.description == long_desc
    end

    test "handles special characters in name" do
      special_name = "Test 测试 🎉 <>&\""
      assert {:ok, context} = Context.create(special_name, nil)
      assert context.name == special_name
    end

    test "handles newlines in description" do
      desc_with_newlines = "Line 1\nLine 2\nLine 3"
      assert {:ok, context} = Context.create("Test", desc_with_newlines)
      assert context.description == desc_with_newlines
    end
  end
end

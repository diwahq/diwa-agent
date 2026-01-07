defmodule DiwaAgent.Tools.ExecutorTest do
  use ExUnit.Case, async: false
  alias DiwaAgent.Tools.Executor
  alias DiwaAgent.Storage.{Context, Memory}
  import DiwaAgent.TestHelper

  setup do
    # Setup test database
    db_path = setup_test_db()
    start_database()

    on_exit(fn -> cleanup_test_db(db_path) end)

    :ok
  end

  describe "create_context tool" do
    test "creates context with name and description" do
      result =
        Executor.execute("create_context", %{
          "name" => "Test Project",
          "description" => "A test project"
        })

      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      assert text =~ "created successfully"
      assert text =~ "Test Project"
    end

    test "creates context with name only" do
      result = Executor.execute("create_context", %{"name" => "Minimal"})

      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      assert text =~ "created successfully"
    end

    test "returns error for missing name" do
      result = Executor.execute("create_context", %{})

      assert %{ "content" => [%{ "type" => "text",  "text" => text}],  "isError" => true} = result
      assert text =~ "Error"
    end
  end

  describe "list_contexts tool" do
    test "lists all contexts" do
      Context.create("Project 1", "Description 1")
      Context.create("Project 2", "Description 2")

      result = Executor.execute("list_contexts", %{})

      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      assert text =~ "Project 1"
      assert text =~ "Project 2"
    end

    test "shows message when no contexts exist" do
      result = Executor.execute("list_contexts", %{})

      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      assert text =~ "No contexts" or text =~ "contexts found"
    end
  end

  describe "get_context tool" do
    test "retrieves context by ID" do
      {:ok, context} = Context.create("Test", "Description")

      result = Executor.execute("get_context", %{"context_id" => context.id})

      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      assert text =~ "Test"
      assert text =~ "Description"
    end

    test "shows memory count" do
      {:ok, context} = Context.create("Test", nil)
      Memory.add(context.id, "Memory 1", nil)
      Memory.add(context.id, "Memory 2", nil)

      result = Executor.execute("get_context", %{"context_id" => context.id})

      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      assert text =~ "2"
      assert text =~ "Memories"
    end

    test "returns error for non-existent context" do
      fake_id = "00000000-0000-0000-0000-000000000000"
      result = Executor.execute("get_context", %{"context_id" => fake_id})

      assert %{ "content" => [%{ "type" => "text",  "text" => _text}],  "isError" => true} = result
    end
  end

  describe "update_context tool" do
    test "updates context name" do
      {:ok, context} = Context.create("Old Name", "Description")

      result =
        Executor.execute("update_context", %{
          "context_id" => context.id,
          "name" => "New Name"
        })

      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      assert text =~ "updated successfully"

      {:ok, updated} = Context.get(context.id)
      assert updated.name == "New Name"
    end

    test "updates context description" do
      {:ok, context} = Context.create("Name", "Old Description")

      result =
        Executor.execute("update_context", %{
          "context_id" => context.id,
          "description" => "New Description"
        })

      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      assert text =~ "updated successfully"
    end

    test "returns error for non-existent context" do
      fake_id = "00000000-0000-0000-0000-000000000000"

      result =
        Executor.execute("update_context", %{
          "context_id" => fake_id,
          "name" => "New Name"
        })

      assert %{ "content" => [%{ "type" => "text",  "text" => _text}],  "isError" => true} = result
    end
  end

  describe "delete_context tool" do
    test "deletes existing context" do
      {:ok, context} = Context.create("To Delete", nil)

      result = Executor.execute("delete_context", %{"context_id" => context.id})

      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      assert text =~ "deleted successfully"

      assert {:error, :not_found} = Context.get(context.id)
    end

    test "returns error for non-existent context" do
      fake_id = "00000000-0000-0000-0000-000000000000"

      result = Executor.execute("delete_context", %{"context_id" => fake_id})

      assert %{ "content" => [%{ "type" => "text",  "text" => _text}],  "isError" => true} = result
    end
  end

  describe "add_memory tool" do
    setup do
      {:ok, context} = Context.create("Test Context", nil)
      {:ok, context: context}
    end

    test "adds memory to context", %{context: context} do
      result =
        Executor.execute("add_memory", %{
          "context_id" => context.id,
          "content" => "Test memory content"
        })

      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      assert text =~ "added successfully"
    end

    test "adds memory with metadata", %{context: context} do
      result =
        Executor.execute("add_memory", %{
          "context_id" => context.id,
          "content" => "Code snippet",
          "metadata" => ~s({"language": "elixir"})
        })

      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      assert text =~ "added successfully"
    end

    test "returns error for non-existent context" do
      fake_id = "00000000-0000-0000-0000-000000000000"

      result =
        Executor.execute("add_memory", %{
          "context_id" => fake_id,
          "content" => "Content"
        })

      assert %{ "content" => [%{ "type" => "text",  "text" => _text}],  "isError" => true} = result
    end
  end

  describe "list_memories tool" do
    setup do
      {:ok, context} = Context.create("Test Context", nil)
      Memory.add(context.id, "Memory 1", nil)
      Memory.add(context.id, "Memory 2", nil)
      {:ok, context: context}
    end

    test "lists memories in context", %{context: context} do
      result = Executor.execute("list_memories", %{"context_id" => context.id})

      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      assert text =~ "Memory 1"
      assert text =~ "Memory 2"
    end

    test "respects limit parameter", %{context: context} do
      Memory.add(context.id, "Memory 3", nil)
      Memory.add(context.id, "Memory 4", nil)

      result =
        Executor.execute("list_memories", %{
          "context_id" => context.id,
          "limit" => 2
        })

      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      # Should mention 2 memories (or show 2 results)
      assert text =~ "2"
    end

    test "shows message when context has no memories" do
      {:ok, empty_context} = Context.create("Empty", nil)

      result = Executor.execute("list_memories", %{"context_id" => empty_context.id})

      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      assert text =~ "No memories" or text =~ "0 memor"
    end
  end

  describe "get_memory tool" do
    setup do
      {:ok, context} = Context.create("Test Context", nil)
      {:ok, memory} = Memory.add(context.id, "Test content", nil)
      {:ok, memory: memory}
    end

    test "retrieves memory by ID", %{memory: memory} do
      result = Executor.execute("get_memory", %{"memory_id" => memory.id})

      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      assert text =~ "Test content"
    end

    test "returns error for non-existent memory" do
      fake_id = "00000000-0000-0000-0000-000000000000"

      result = Executor.execute("get_memory", %{"memory_id" => fake_id})

      assert %{ "content" => [%{ "type" => "text",  "text" => _text}],  "isError" => true} = result
    end
  end

  describe "update_memory tool" do
    setup do
      {:ok, context} = Context.create("Test Context", nil)
      {:ok, memory} = Memory.add(context.id, "Old content", nil)
      {:ok, memory: memory}
    end

    test "updates memory content", %{memory: memory} do
      result =
        Executor.execute("update_memory", %{
          "memory_id" => memory.id,
          "content" => "New content"
        })

      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      assert text =~ "updated successfully"

      {:ok, updated} = Memory.get(memory.id)
      assert updated.content == "New content"
    end

    test "returns error for non-existent memory" do
      fake_id = "00000000-0000-0000-0000-000000000000"

      result =
        Executor.execute("update_memory", %{
          "memory_id" => fake_id,
          "content" => "New content"
        })

      assert %{ "content" => [%{ "type" => "text",  "text" => _text}],  "isError" => true} = result
    end
  end

  describe "delete_memory tool" do
    setup do
      {:ok, context} = Context.create("Test Context", nil)
      {:ok, memory} = Memory.add(context.id, "To delete", nil)
      {:ok, memory: memory}
    end

    test "deletes existing memory", %{memory: memory} do
      result = Executor.execute("delete_memory", %{"memory_id" => memory.id})

      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      assert text =~ "deleted successfully"

      {:ok, deleted} = Memory.get(memory.id)
      assert deleted.deleted_at != nil
    end

    test "returns error for non-existent memory" do
      fake_id = "00000000-0000-0000-0000-000000000000"

      result = Executor.execute("delete_memory", %{"memory_id" => fake_id})

      assert %{ "content" => [%{ "type" => "text",  "text" => _text}],  "isError" => true} = result
    end
  end

  describe "search_memories tool" do
    setup do
      {:ok, context} = Context.create("Test Context", nil)
      Memory.add(context.id, "Phoenix LiveView is awesome", nil)
      Memory.add(context.id, "Elixir has pattern matching", nil)
      Memory.add(context.id, "Phoenix uses Ecto", nil)
      {:ok, context: context}
    end

    test "searches across all contexts" do
      result = Executor.execute("search_memories", %{"query" => "Phoenix"})

      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      assert text =~ "Phoenix"
      assert text =~ "2" or text =~ "result"
    end

    test "searches within specific context", %{context: context} do
      result =
        Executor.execute("search_memories", %{
          "query" => "Phoenix",
          "context_id" => context.id
        })

      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      assert text =~ "Phoenix"
    end

    test "returns message when no results found" do
      result = Executor.execute("search_memories", %{"query" => "NonExistent"})

      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      IO.inspect(text, label: "Search Memories Text")
      assert text =~ "No memories found" or text =~ "0 result" or text =~ "fuzzy matches"
    end
  end

  describe "unknown tool" do
    test "returns error for unknown tool name" do
      result = Executor.execute("unknown_tool", %{})

      assert %{ "content" => [%{ "type" => "text",  "text" => text}],  "isError" => true} = result
      assert text =~ "Unknown tool"
    end
  end

  describe "response format" do
    test "all tools return proper MCP response structure" do
      {:ok, context} = Context.create("Test", nil)

      tools_and_args = [
        {"create_context", %{"name" => "Test"}},
        {"list_contexts", %{}},
        {"get_context", %{"context_id" => context.id}},
        {"update_context", %{"context_id" => context.id, "name" => "Updated"}},
        {"add_memory", %{"context_id" => context.id, "content" => "Content"}},
        {"list_memories", %{"context_id" => context.id}},
        {"search_memories", %{"query" => "test"}}
      ]

      for {tool_name, args} <- tools_and_args do
        result = Executor.execute(tool_name, args)

        # Check response structure
        assert is_map(result)
        assert Map.has_key?(result, "content")
        assert is_list(result["content"])
        assert length(result["content"]) > 0

        # Check content items
        [first_item | _] = result["content"]
        assert is_map(first_item)
        assert Map.has_key?(first_item, "type")
        assert Map.has_key?(first_item, "text")
      end
    end
  end

  describe "get_active_handoff tool" do
    setup do
      {:ok, context} = Context.create("Handoff Context", nil)
      {:ok, context: context}
    end

    test "retrieves valid handoff note", %{context: context} do
      meta = %{
        "type" => "handoff",
        "next_steps" => ["Step 1", "Step 2"],
        "active_files" => ["file1.ex"]
      }
      Memory.add(context.id, "Summary", %{metadata: Jason.encode!(meta)})
      
      result = Executor.execute("get_active_handoff", %{"context_id" => context.id})
      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      assert text =~ "Step 1"
      assert text =~ "file1.ex"
    end

    test "handles handoff with missing metadata fields", %{context: context} do
      # Minimal handoff with just type
      meta = %{"type" => "handoff"}
      Memory.add(context.id, "Summary Only", %{metadata: Jason.encode!(meta)})
      
      result = Executor.execute("get_active_handoff", %{"context_id" => context.id})
      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      assert text =~ "Summary Only"
    end
  end
end

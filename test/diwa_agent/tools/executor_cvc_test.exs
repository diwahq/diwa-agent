defmodule DiwaAgent.Tools.ExecutorCVCTest do
  use ExUnit.Case, async: false
  alias DiwaAgent.Tools.Executor
  alias DiwaAgent.Storage.Context
  import DiwaAgent.TestHelper

  setup do
    # Setup test database
    db_path = setup_test_db()
    start_database()

    on_exit(fn -> cleanup_test_db(db_path) end)

    :ok
  end

  describe "resolve_context" do
    test "finds context by exact name" do
      {:ok, ctx} = Context.create("My Project", "Description")
      
      result = Executor.execute("resolve_context", %{"name" => "My Project"})
      assert %{content: [%{type: "text", text: text}]} = result
      assert text =~ "Context found: 'My Project'"
      assert text =~ "ID: #{ctx.id}"
    end

    test "finds context by case-insensitive name" do
      {:ok, ctx} = Context.create("Another Project", "Description")
      
      result = Executor.execute("resolve_context", %{"name" => "another PROJECT"})
      assert %{content: [%{type: "text", text: text}]} = result
      assert text =~ "Context found: 'Another Project'"
      assert text =~ "ID: #{ctx.id}"
    end
    
    test "finds context by ID if name is UUID" do
       {:ok, ctx} = Context.create("UUID Project", "Description")
       
       result = Executor.execute("resolve_context", %{"name" => ctx.id})
       assert %{content: [%{type: "text", text: text}]} = result
       assert text =~ "Context found: 'UUID Project'"
       assert text =~ "ID: #{ctx.id}"
    end

    test "returns error for non-existent context" do
      result = Executor.execute("resolve_context", %{"name" => "NonExistent"})
      assert %{content: [%{type: "text", text: text}], isError: true} = result
      assert text =~ "Context not found with name: 'NonExistent'"
    end
  end

  describe "verify_context_integrity" do
    test "verifies valid chain (stubbed)" do
      {:ok, ctx} = Context.create("Verified Project", "Desc")
      # Add a memory to generate a commit
      Executor.execute("add_memory", %{"context_id" => ctx.id, "content" => "Mem 1"})
      
      result = Executor.execute("verify_context_integrity", %{"context_id" => ctx.id})
      assert %{content: [%{type: "text", text: text}]} = result
      assert text =~ "no version history"
    end
    
     test "reports no history for empty context" do
      {:ok, ctx} = Context.create("Empty Project", "Desc")
      # No additions, so no commits
      
      result = Executor.execute("verify_context_integrity", %{"context_id" => ctx.id})
      assert %{content: [%{type: "text", text: text}]} = result
      assert text =~ "no version history"
    end
  end
end

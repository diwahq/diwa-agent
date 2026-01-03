defmodule BridgeToolsTest do
  use ExUnit.Case

  alias DiwaAgent.Storage.Context
  alias DiwaAgent.Tools.Executor

  setup do
    # Clean database before each test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(DiwaAgent.Repo)
    :ok
  end

  describe "Bridge Coordination Tools" do
    test "set_project_status and get_project_status" do
      {:ok, ctx} = Context.create("Bridge Test", "Testing bridge tools")

      # Set status
      result =
        Executor.execute("set_project_status", %{
          "context_id" => ctx.id,
          "status" => "Implementation",
          "completion_pct" => 45,
          "notes" => "Working on bridge tools"
        })

      assert result.content
      assert Enum.any?(result.content, fn c -> String.contains?(c.text, "Implementation") end)

      # Get status
      result = Executor.execute("get_project_status", %{"context_id" => ctx.id})
      assert result.content

      assert Enum.any?(result.content, fn c ->
               String.contains?(c.text, "Implementation") and String.contains?(c.text, "45%")
             end)
    end

    test "add_requirement and mark_requirement_complete" do
      {:ok, ctx} = Context.create("Bridge Test", "Testing requirements")

      # Add requirement
      result =
        Executor.execute("add_requirement", %{
          "context_id" => ctx.id,
          "title" => "SQLite JSON support",
          "description" => "Ensure metadata is queryable via LIKE pattern",
          "priority" => "High"
        })

      assert result.content
      text = hd(result.content).text
      assert String.contains?(text, "SQLite JSON support")

      # Extract requirement ID from response
      [_, req_id] = Regex.run(~r/ID: ([0-9a-f-]+)/, text)

      # Mark complete
      result = Executor.execute("mark_requirement_complete", %{"requirement_id" => req_id})
      assert result.content
      assert Enum.any?(result.content, fn c -> String.contains?(c.text, "complete") end)
    end

    test "record_lesson and search_lessons" do
      {:ok, ctx} = Context.create("Bridge Test", "Testing lessons")

      # Record lesson
      result =
        Executor.execute("record_lesson", %{
          "context_id" => ctx.id,
          "title" => "Metadata Filtering",
          "content" => "Use LIKE pattern with double quotes for JSON type matching",
          "category" => "Storage"
        })

      assert result.content
      assert Enum.any?(result.content, fn c -> String.contains?(c.text, "Metadata Filtering") end)

      # Search lessons
      result = Executor.execute("search_lessons", %{"query" => "LIKE"})
      assert result.content
      text = hd(result.content).text
      assert String.contains?(text, "Metadata Filtering") or String.contains?(text, "No lessons")
    end

    test "flag_blocker and resolve_blocker" do
      {:ok, ctx} = Context.create("Bridge Test", "Testing blockers")

      # Flag blocker
      result =
        Executor.execute("flag_blocker", %{
          "context_id" => ctx.id,
          "title" => "NIF loading in escripts",
          "description" => "Native libraries like exqlite fail to load from escript archive",
          "severity" => "Critical"
        })

      assert result.content
      text = hd(result.content).text
      assert String.contains?(text, "BLOCKER")

      # Extract blocker ID
      [_, blocker_id] = Regex.run(~r/ID: ([0-9a-f-]+)/, text)

      # Resolve blocker
      result =
        Executor.execute("resolve_blocker", %{
          "blocker_id" => blocker_id,
          "resolution" => "Used koda.sh wrapper script to bypass escript archive limitations"
        })

      assert result.content
      assert Enum.any?(result.content, fn c -> String.contains?(c.text, "resolved") end)
    end

    test "set_handoff_note and get_active_handoff" do
      {:ok, ctx} = Context.create("Bridge Test", "Testing handoff")

      # Set handoff
      result =
        Executor.execute("set_handoff_note", %{
          "context_id" => ctx.id,
          "summary" => "Completed implementation of 10 bridge tools",
          "next_steps" => ["Verify with bash script", "Update docs", "Commit changes"],
          "active_files" => ["executor.ex", "definitions.ex"]
        })

      assert result.content
      assert Enum.any?(result.content, fn c -> String.contains?(c.text, "Handoff") end)

      # Get handoff
      result = Executor.execute("get_active_handoff", %{"context_id" => ctx.id})
      assert result.content
      text = hd(result.content).text
      assert String.contains?(text, "Completed implementation")
      assert String.contains?(text, "executor.ex")
    end
  end
end

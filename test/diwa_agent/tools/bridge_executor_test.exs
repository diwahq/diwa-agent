defmodule DiwaAgent.Tools.BridgeExecutorTest do
  use ExUnit.Case, async: false
  alias DiwaAgent.Tools.Executor
  alias DiwaAgent.Storage.{Context, Memory, Task}
  import DiwaAgent.TestHelper

  setup do
    db_path = setup_test_db()
    start_database()
    on_exit(fn -> cleanup_test_db(db_path) end)

    {:ok, context} = Context.create("Bridge Test Project", "Testing coordination tools")
    {:ok, context: context}
  end

  describe "Bridge Coordination tools" do
    test "set_project_status and get_project_status", %{context: context} do
      # Set status
      args = %{
        "context_id" => context.id,
        "status" => "Implementation",
        "completion_pct" => 45,
        "notes" => "Halfway there"
      }

      result = Executor.execute("set_project_status", args)
      assert %{content: [%{type: "text", text: text}]} = result
      assert text =~ "updated to 'Implementation' (45%)"

      # Get status
      get_res = Executor.execute("get_project_status", %{"context_id" => context.id})
      assert %{content: [%{type: "text", text: get_text}]} = get_res
      assert get_text =~ "Status: Implementation"
      assert get_text =~ "Progress: 45%"
      assert get_text =~ "Halfway there"
    end

    test "add_requirement and mark_requirement_complete", %{context: context} do
      # Add requirement
      args = %{
        "context_id" => context.id,
        "title" => "FTS5 Search",
        "description" => "Must use SQLite FTS5",
        "priority" => "High"
      }

      result = Executor.execute("add_requirement", args)
      assert %{content: [%{type: "text", text: text}]} = result
      assert text =~ "Requirement added: 'FTS5 Search'"

      # Extract ID from text (simple hack for test)
      [_, req_id] = Regex.run(~r/ID: ([\w-]+)/, text)

      # Mark complete
      comp_res = Executor.execute("mark_requirement_complete", %{"requirement_id" => req_id})
      assert %{content: [%{type: "text", text: comp_text}]} = comp_res
      assert comp_text =~ "marked as complete"

      # Verify content updated
      # Verify status updated
      {:ok, req} = Task.get(req_id)
      assert req.status == "completed"
    end

    test "record_lesson and search_lessons", %{context: context} do
      # Record lesson
      args = %{
        "context_id" => context.id,
        "title" => "NIF Loading",
        "content" => "Don't use escript for NIFs",
        "category" => "Architecture"
      }

      result = Executor.execute("record_lesson", args)
      assert %{content: [%{type: "text", text: text}]} = result
      assert text =~ "Lesson recorded: 'NIF Loading'"

      # Search lessons
      search_res = Executor.execute("search_lessons", %{"query" => "escript"})
      assert %{content: [%{type: "text", text: search_text}]} = search_res
      assert search_text =~ "NIF Loading"
      assert search_text =~ "Architecture"
    end

    test "flag_blocker and resolve_blocker", %{context: context} do
      # Flag blocker
      args = %{
        "context_id" => context.id,
        "title" => "SSL Issues",
        "description" => "Claude needs HTTPS",
        "severity" => "Critical"
      }

      result = Executor.execute("flag_blocker", args)
      assert %{content: [%{type: "text", text: text}]} = result
      assert text =~ "BLOCKER FLAGGED"

      [_, blocker_id] = Regex.run(~r/ID: ([\w-]+)/, text)

      # Resolve blocker
      res_args = %{
        "blocker_id" => blocker_id,
        "resolution" => "Used Cloudflare Tunnel"
      }

      res_result = Executor.execute("resolve_blocker", res_args)
      assert %{content: [%{type: "text", text: res_text}]} = res_result
      assert res_text =~ "marked as resolved"

      # Verify content
      {:ok, blocker} = Memory.get(blocker_id)
      assert blocker.content =~ "[RESOLVED]"
      assert blocker.content =~ "Cloudflare Tunnel"
    end

    test "set_handoff_note and get_active_handoff", %{context: context} do
      # Set handoff
      args = %{
        "context_id" => context.id,
        "summary" => "Wrapped up tools",
        "next_steps" => ["Docs", "Deploy"],
        "active_files" => ["executor.ex"]
      }

      result = Executor.execute("set_handoff_note", args)
      assert %{content: [%{type: "text", text: text}]} = result
      assert text =~ "Handoff note recorded"

      # Get handoff
      get_res = Executor.execute("get_active_handoff", %{"context_id" => context.id})
      assert %{content: [%{type: "text", text: get_text}]} = get_res
      assert get_text =~ "Summary: Wrapped up tools"
      assert get_text =~ "- Docs"
      assert get_text =~ "- executor.ex"
    end

    test "get_pending_tasks", %{context: context} do
      # Add strict priority tasks
      Executor.execute("add_requirement", %{
        "context_id" => context.id,
        "title" => "Low Priority",
        "description" => "desc",
        "priority" => "Low"
      })

      Executor.execute("add_requirement", %{
        "context_id" => context.id,
        "title" => "High Priority",
        "description" => "desc",
        "priority" => "High"
      })

      # Get pending tasks
      result = Executor.execute("get_pending_tasks", %{"context_id" => context.id, "limit" => 5})
      assert %{content: [%{type: "text", text: text}]} = result

      # Should be ordered High -> Low
      assert text =~ "High Priority"
      assert text =~ "Low Priority"
      # Simple regex check for ordering if possible, or just presence for now
    end

    test "log_progress", %{context: context} do
      result =
        Executor.execute("log_progress", %{
          "context_id" => context.id,
          "message" => "Implemented tests",
          "tags" => "testing"
        })

      assert %{content: [%{type: "text", text: text}]} = result
      assert text =~ "Progress logged: Implemented tests"
    end

    test "get_resume_context", %{context: context} do
      # 1. Set Handoff
      Executor.execute("set_handoff_note", %{
        "context_id" => context.id,
        "summary" => "End of day",
        "next_steps" => ["Sleep"],
        "active_files" => []
      })

      # 2. Add Requirement
      Executor.execute("add_requirement", %{
        "context_id" => context.id,
        "title" => "Wake up",
        "description" => "desc",
        "priority" => "High"
      })

      # 3. Flag Blocker
      Executor.execute("flag_blocker", %{
        "context_id" => context.id,
        "title" => "No Coffee",
        "description" => "Critical",
        "severity" => "Critical"
      })

      # Get Resume Context
      result = Executor.execute("get_resume_context", %{"context_id" => context.id})
      assert %{content: [%{type: "text", text: text}]} = result

      assert text =~ "SESSION START CONTEXT"
      # Handoff
      assert text =~ "End of day"
      # Pending Task
      assert text =~ "Wake up"
      # Blocker
      assert text =~ "No Coffee"
    end
  end
end

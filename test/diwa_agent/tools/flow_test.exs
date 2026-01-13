defmodule DiwaAgent.Tools.FlowTest do
  use ExUnit.Case, async: false
  alias DiwaAgent.Tools.Flow
  alias DiwaAgent.Storage.{Context, Memory}
  import DiwaAgent.TestHelper

  setup do
    db_path = setup_test_db()
    start_database()
    on_exit(fn -> cleanup_test_db(db_path) end)
    :ok
  end

  defp create_context_with_role(role_name) do
    {:ok, ctx} = Context.create("Flow Test", "Testing @flow")
    # Add memory to define role. Content is 2nd arg.
    Memory.add(ctx.id, "System setup: actor #{role_name}", nil) 
    ctx
  end

  describe "Core Logic Scenarios (P0)" do
    test "P0: Planner detects critical blocker" do
      ctx = create_context_with_role("claude")
      # Add blocker
      Memory.add(ctx.id, "API is down", %{tags: ["blocker"]})
      
      result = Flow.execute("determine_workflow", %{"context_id" => ctx.id})
      response = get_in(result, ["content", Access.at(0), "text"])

      assert response =~ "🚨"
      assert response =~ "Planner Mode (P0)"
      assert response =~ "@resolve_blocker"
      assert response =~ "Critical blockers detected"
    end

    test "P0: Coder detects knowledge conflict" do
      ctx = create_context_with_role("antigravity")
      Memory.add(ctx.id, "Conflict A", %{tags: ["conflict"]})

      result = Flow.execute("determine_workflow", %{"context_id" => ctx.id})
      response = get_in(result, ["content", Access.at(0), "text"])

      assert response =~ "🚨"
      assert response =~ "Coder Mode (P0)"
      assert response =~ "@resolve_conflict"
    end

    test "P0: Coder detects failing tests" do
      ctx = create_context_with_role("antigravity")
      Memory.add(ctx.id, "Test Failed", %{tags: ["test_failure"]})

      result = Flow.execute("determine_workflow", %{"context_id" => ctx.id})
      response = get_in(result, ["content", Access.at(0), "text"])

      assert response =~ "🚨"
      assert response =~ "P0"
      assert response =~ "@test"
      assert response =~ "tests are failing"
    end
  end

  describe "Core Logic Scenarios (P1)" do
    test "P1: Coder receives handoff" do
      ctx = create_context_with_role("antigravity")
      Memory.add(ctx.id, "Handoff Note", %{tags: ["handoff_to_coder"]})

      result = Flow.execute("determine_workflow", %{"context_id" => ctx.id})
      response = get_in(result, ["content", Access.at(0), "text"])

      assert response =~ "⚡"
      assert response =~ "P1"
      assert response =~ "@resume"
      assert response =~ "New handoff received"
    end

    test "P1: Coder resumes implementation (Recent Files)" do
      ctx = create_context_with_role("antigravity")
      # Add memory with active files
      meta = %{"active_files" => ["lib/foo.ex"]}
      Memory.add(ctx.id, "Edit foo", %{metadata: meta})

      result = Flow.execute("determine_workflow", %{"context_id" => ctx.id})
      response = get_in(result, ["content", Access.at(0), "text"])

      assert response =~ "⚡"
      assert response =~ "P1"
      assert response =~ "@ls"
      assert response =~ "Resume work on recently edited files"
      assert response =~ "lib/foo.ex"
    end

    test "P1: Planner prioritizes tasks" do
      ctx = create_context_with_role("claude")
      Memory.add(ctx.id, "Req 1", %{tags: ["requirement"]})

      result = Flow.execute("determine_workflow", %{"context_id" => ctx.id})
      response = get_in(result, ["content", Access.at(0), "text"])

      assert response =~ "⚡"
      assert response =~ "P1"
      assert response =~ "@todo"
      assert response =~ "high-priority tasks pending"
    end
    
    test "P1: Custom Query overrides P2" do
       ctx = create_context_with_role("claude")
       # Normal state would be P2
       
       result = Flow.execute("determine_workflow", %{"context_id" => ctx.id, "query" => "check status"})
       response = get_in(result, ["content", Access.at(0), "text"])
       
       assert response =~ "⚡" # Upgraded to P1
       assert response =~ "@chat"
       assert response =~ "User specified intent"
    end
  end

  describe "Core Logic Scenarios (P2/P3)" do
    test "P2: Planner default" do
      ctx = create_context_with_role("claude")
      # No blockers, no tasks

      result = Flow.execute("determine_workflow", %{"context_id" => ctx.id})
      response = get_in(result, ["content", Access.at(0), "text"])

      assert response =~ "🌊"
      assert response =~ "P2"
      assert response =~ "@stat"
      assert response =~ "Review spec status"
    end

    test "P2: Coder default" do
      ctx = create_context_with_role("antigravity")

      result = Flow.execute("determine_workflow", %{"context_id" => ctx.id})
      response = get_in(result, ["content", Access.at(0), "text"])

      assert response =~ "🌊"
      assert response =~ "P2"
      assert response =~ "@stat"
      assert response =~ "Check context health"
    end
    
    test "P3: Start Fresh (No Context logic)" do
       # If passed nil context
       result = Flow.execute("determine_workflow", %{"context_id" => nil})
       response = get_in(result, ["content", Access.at(0), "text"])
       
       assert response =~ "🌱"
       assert response =~ "P3"
       assert response =~ "@start"
    end
  end
  
  describe "Role Detection" do
     test "detects 'human' as planner" do
        ctx = create_context_with_role("human")
        result = Flow.execute("determine_workflow", %{"context_id" => ctx.id})
        response = get_in(result, ["content", Access.at(0), "text"])
        assert response =~ "Planner Mode"
     end
     
     test "detects 'cursor' as coder" do
        ctx = create_context_with_role("cursor")
        result = Flow.execute("determine_workflow", %{"context_id" => ctx.id})
        response = get_in(result, ["content", Access.at(0), "text"])
        assert response =~ "Coder Mode"
     end
  end
end

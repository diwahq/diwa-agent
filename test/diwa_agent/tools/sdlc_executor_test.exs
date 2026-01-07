defmodule DiwaAgent.Tools.SDLCExecutorTest do
  use ExUnit.Case, async: false
  alias DiwaAgent.Tools.Executor
  alias DiwaAgent.Storage.{Context, Memory, Task}
  import DiwaAgent.TestHelper

  setup do
    db_path = setup_test_db()
    start_database()
    on_exit(fn -> cleanup_test_db(db_path) end)

    {:ok, context} = Context.create("SDLC Executor Test", "Testing new tools")
    {:ok, context: context}
  end

  describe "SDLC tools" do
    test "add_memories batch tool", %{context: context} do
      args = %{
        "context_id" => context.id,
        "memories" => [
          %{"content" => "Batch 1", "tags" => "batch"},
          %{"content" => "Batch 2", "actor" => "testbot"}
        ]
      }

      result = Executor.execute("add_memories", args)
      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      assert text =~ "Successfully added 2 of 2"

      {:ok, count} = Memory.count(context.id)
      assert count == 2
    end

    test "record_decision tool", %{context: context} do
      args = %{
        "context_id" => context.id,
        "decision" => "Use Elixir",
        "rationale" => "Scalability",
        "alternatives" => "Rust, Go"
      }

      result = Executor.execute("record_decision", args)
      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      assert text =~ "Decision recorded"

      {:ok, memories} = Memory.list_by_tag(context.id, "decision")
      assert length(memories) == 1
      assert hd(memories).content =~ "Decision: Use Elixir"
    end

    test "record_deployment tool", %{context: context} do
      args = %{
        "context_id" => context.id,
        "environment" => "prod",
        "version" => "v1.0.0",
        "status" => "success"
      }

      result = Executor.execute("record_deployment", args)
      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      assert text =~ "Deployment"
    end

    test "log_incident tool", %{context: context} do
      args = %{
        "context_id" => context.id,
        "title" => "DB Outage",
        "description" => "Disk full",
        "severity" => "critical"
      }

      result = Executor.execute("log_incident", args)
      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      assert text =~ "Incident logged"
    end

    test "record_pattern tool", %{context: context} do
      args = %{
        "context_id" => context.id,
        "name" => "Singleton",
        "description" => "One instance"
      }

      result = Executor.execute("record_pattern", args)
      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      assert text =~ "Pattern recorded"
    end

    test "record_review tool", %{context: context} do
      args = %{
        "context_id" => context.id,
        "title" => "Security Review",
        "summary" => "Looks good",
        "status" => "approved"
      }

      result = Executor.execute("record_review", args)
      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      assert text =~ "Review recorded"
    end

    test "prioritize_requirement tool", %{context: context} do
      # Create a requirement first (Task)
      {:ok, req} = Task.add(context.id, "Req", "Description", "Low")

      args = %{"requirement_id" => req.id, "priority" => "High"}
      result = Executor.execute("prioritize_requirement", args)

      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      assert text =~ "priority updated to High"

      {:ok, updated} = Task.get(req.id)
      assert updated.priority == "High"
    end

    test "list_by_tag tool", %{context: context} do
      Memory.add(context.id, "Tagged Content", %{tags: "searchable"})

      result =
        Executor.execute("list_by_tag", %{"context_id" => context.id, "tag" => "searchable"})

      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      assert text =~ "Tagged Content"
    end

    test "export_context tool", %{context: context} do
      Memory.add(context.id, "Mem 1", %{actor: "bot"})

      # Markdown
      result_md =
        Executor.execute("export_context", %{"context_id" => context.id, "format" => "markdown"})

      assert %{ "content" => [%{ "type" => "text",  "text" => text_md}]} = result_md
      assert text_md =~ "# Export: SDLC Executor Test"
      assert text_md =~ "Mem 1"

      # JSON
      result_json =
        Executor.execute("export_context", %{"context_id" => context.id, "format" => "json"})

      assert %{ "content" => [%{ "type" => "text",  "text" => text_json}]} = result_json
      assert text_json =~ "\"exported_at\""
    end

    test "hierarchy tools", %{context: context} do
      {:ok, p} = Memory.add(context.id, "Parent", %{})
      {:ok, c} = Memory.add(context.id, "Child", %{})

      # link_memories
      res_link = Executor.execute("link_memories", %{"parent_id" => p.id, "child_id" => c.id})
      assert %{ "content" => [%{ "type" => "text",  "text" => text_link}]} = res_link
      assert text_link =~ "Linked"

      # get_memory_tree
      res_tree = Executor.execute("get_memory_tree", %{"root_id" => p.id})
      assert %{ "content" => [%{ "type" => "text",  "text" => text_tree}]} = res_tree
      assert text_tree =~ "Parent"
      assert text_tree =~ "Child"
    end

    test "record_analysis_result tool", %{context: context} do
      args = %{
        "context_id" => context.id,
        "scanner_name" => "Mix Audit",
        "findings" => "Clear",
        "severity" => "info"
      }

      result = Executor.execute("record_analysis_result", args)
      assert %{ "content" => [%{ "type" => "text",  "text" => text}]} = result
      assert text =~ "Analysis result"
    end
  end
end

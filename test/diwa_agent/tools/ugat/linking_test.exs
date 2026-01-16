defmodule DiwaAgent.Tools.Ugat.LinkingTest do
  use ExUnit.Case, async: false
  alias DiwaAgent.Tools.Ugat
  alias DiwaAgent.Storage.Context
  import DiwaAgent.TestHelper

  setup do
    db_path = setup_test_db()
    start_database()
    on_exit(fn -> cleanup_test_db(db_path) end)
    :ok
  end

  describe "MCP Tool Wrappers" do
    setup do
      {:ok, ctx_1} = Context.create("Project Alpha", nil)
      {:ok, ctx_2} = Context.create("Project Beta", nil)
      %{c1: ctx_1, c2: ctx_2}
    end

    test "detect_context via execute/2", %{c1: c1} do
      {:ok, _} =
        DiwaAgent.Storage.Context.Ugat.add_binding(c1.id, "git_remote", "https://git.com/alpha")

      response =
        Ugat.execute("detect_context", %{
          "type" => "git_remote",
          "value" => "https://git.com/alpha"
        })

      assert response["isError"] == false
      assert Enum.at(response["content"], 0)["text"] =~ "Context Detected"
      assert Enum.at(response["content"], 0)["text"] =~ "Project Alpha"
    end

    test "bind_context via execute/2", %{c1: c1} do
      response =
        Ugat.execute("bind_context", %{
          "context_id" => c1.id,
          "type" => "path",
          "value" => "/tmp/project"
        })

      assert response["isError"] == false
      assert Enum.at(response["content"], 0)["text"] =~ "Context Bound Successfully"
    end

    test "link_contexts via execute/2", %{c1: c1, c2: c2} do
      response =
        Ugat.execute("link_contexts", %{
          "source_context_id" => c1.id,
          "target_context_id" => c2.id,
          "relationship_type" => "depends_on"
        })

      assert response["isError"] == false
      assert Enum.at(response["content"], 0)["text"] =~ "Contexts Linked"

      # Verify link exists
      links = DiwaAgent.Storage.Context.Ugat.get_relationships(c1.id, :outgoing)
      assert length(links) == 1
    end

    test "get_related_contexts via execute/2", %{c1: c1, c2: c2} do
      {:ok, _} = DiwaAgent.Storage.Context.Ugat.link_contexts(c1.id, c2.id, "depends_on")

      response = Ugat.execute("get_related_contexts", %{"context_id" => c1.id})
      assert response["isError"] == false
      assert Enum.at(response["content"], 0)["text"] =~ "Project Beta"
      assert Enum.at(response["content"], 0)["text"] =~ "depends_on"
    end

    test "get_dependency_chain via execute/2", %{c1: c1} do
      # Single item chain
      response = Ugat.execute("get_dependency_chain", %{"context_id" => c1.id})
      assert response["isError"] == false
      assert Enum.at(response["content"], 0)["text"] =~ "Project Alpha"
    end
  end
end

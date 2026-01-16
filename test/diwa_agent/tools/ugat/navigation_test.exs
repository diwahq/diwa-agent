defmodule DiwaAgent.Tools.Ugat.NavigationTest do
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

  describe "navigate_contexts" do
    setup do
      {:ok, root} = Context.create("Root Project", nil)
      {:ok, child_a} = Context.create("Child A", nil)
      {:ok, child_b} = Context.create("Child B", nil)

      # Create structure: Root -> (contains) -> Child A, Root -> (contains) -> Child B
      DiwaAgent.Storage.Context.Ugat.link_contexts(root.id, child_a.id, "contains")
      DiwaAgent.Storage.Context.Ugat.link_contexts(root.id, child_b.id, "contains")

      %{root: root, child_a: child_a, child_b: child_b}
    end

    test "list current context (ls .)", %{root: root} do
      response =
        Ugat.execute("navigate_contexts", %{
          "context_id" => root.id,
          "target_path" => ".",
          "mode" => "list"
        })

      assert response["isError"] == false
      text = Enum.at(response["content"], 0)["text"]
      assert text =~ "PWD: Root Project"
      assert text =~ "Child A"
      assert text =~ "Child B"
      assert text =~ "contains"
    end

    test "navigate into child by name", %{root: root, child_a: child_a} do
      response =
        Ugat.execute("navigate_contexts", %{
          "context_id" => root.id,
          "target_path" => "Child A",
          "mode" => "list"
        })

      assert response["isError"] == false
      text = Enum.at(response["content"], 0)["text"]
      assert text =~ "PWD: Child A"
      assert text =~ "(#{child_a.id})"
    end

    test "navigate up using ..", %{root: _root, child_a: child_a} do
      # From Child A, '..' should go to Root because Root "contains" Child A
      response =
        Ugat.execute("navigate_contexts", %{
          "context_id" => child_a.id,
          "target_path" => "..",
          "mode" => "list"
        })

      assert response["isError"] == false
      text = Enum.at(response["content"], 0)["text"]
      assert text =~ "PWD: Root Project"
    end

    test "detail view", %{root: root} do
      response =
        Ugat.execute("navigate_contexts", %{
          "context_id" => root.id,
          "target_path" => ".",
          "mode" => "detail"
        })

      assert response["isError"] == false
      text = Enum.at(response["content"], 0)["text"]
      assert text =~ "Root Project"
      assert text =~ "Memories"
    end

    test "tree view", %{root: root} do
      response =
        Ugat.execute("navigate_contexts", %{
          "context_id" => root.id,
          "target_path" => ".",
          "mode" => "tree"
        })

      assert response["isError"] == false
      text = Enum.at(response["content"], 0)["text"]
      assert text =~ "Root Project"
      assert text =~ "-- contains --> Child A"
    end
  end
end

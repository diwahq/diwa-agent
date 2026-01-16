defmodule DiwaAgent.Storage.Context.UgatTest do
  use ExUnit.Case, async: false
  alias DiwaAgent.Storage.Context
  alias DiwaAgent.Storage.Context.Ugat
  import DiwaAgent.TestHelper

  setup do
    db_path = setup_test_db()
    start_database()
    on_exit(fn -> cleanup_test_db(db_path) end)
    :ok
  end

  describe "Context Bindings (Auto-Detection)" do
    test "add_binding/4 and list_bindings/1" do
      {:ok, ctx} = Context.create("Binding Test", "Testing bindings")

      assert {:ok, binding} =
               Ugat.add_binding(ctx.id, "git_remote", "https://github.com/diwa/agent.git")

      assert binding.binding_type == "git_remote"
      assert binding.value == "https://github.com/diwa/agent.git"
      assert binding.context_id == ctx.id

      # List bindings
      bindings = Ugat.list_bindings(ctx.id)
      assert length(bindings) == 1
      assert hd(bindings).id == binding.id
    end

    test "detect_context/2" do
      {:ok, ctx} = Context.create("Detect Me", "Testing detection")
      {:ok, _} = Ugat.add_binding(ctx.id, "path", "/Users/ei/codes/diwa")

      # Should detect
      assert result = Ugat.detect_context("path", "/Users/ei/codes/diwa")
      assert result.context.id == ctx.id

      # Should not detect invalid value
      assert nil == Ugat.detect_context("path", "/invalid/path")
    end

    test "remove_binding/1" do
      {:ok, ctx} = Context.create("Remove Binding", nil)
      {:ok, b} = Ugat.add_binding(ctx.id, "env_var", "DIWA_PROJECT=1")

      assert {:ok, _} = Ugat.remove_binding(b.id)
      assert [] == Ugat.list_bindings(ctx.id)
    end
  end

  describe "Context Relationships (Linking)" do
    setup do
      {:ok, ctx_a} = Context.create("Context A", nil)
      {:ok, ctx_b} = Context.create("Context B", nil)
      {:ok, ctx_c} = Context.create("Context C", nil)
      %{a: ctx_a, b: ctx_b, c: ctx_c}
    end

    test "link_contexts/4 basic linking", %{a: a, b: b} do
      assert {:ok, rel} = Ugat.link_contexts(a.id, b.id, "depends_on")
      assert rel.source_context_id == a.id
      assert rel.target_context_id == b.id
      assert rel.relationship_type == "depends_on"
    end

    test "link_contexts/4 prevents self-reference", %{a: a} do
      assert {:error, :self_reference} = Ugat.link_contexts(a.id, a.id, "depends_on")
    end

    test "link_contexts/4 prevents circular dependency", %{a: a, b: b, c: c} do
      # A -> B
      {:ok, _} = Ugat.link_contexts(a.id, b.id, "depends_on")
      # B -> C
      {:ok, _} = Ugat.link_contexts(b.id, c.id, "depends_on")

      # C -> A (Cycle!)
      assert {:error, :circular_dependency_detected} =
               Ugat.link_contexts(c.id, a.id, "depends_on")
    end

    test "link_contexts/4 allows non-dependency cycles (e.g. complements)", %{a: a, b: b} do
      # A <-> B (complements)
      assert {:ok, _} = Ugat.link_contexts(a.id, b.id, "complements")
      assert {:ok, _} = Ugat.link_contexts(b.id, a.id, "complements")
    end

    test "get_relationships/2 directions", %{a: a, b: b} do
      {:ok, _} = Ugat.link_contexts(a.id, b.id, "depends_on")

      # Outgoing from A
      outgoing = Ugat.get_relationships(a.id, :outgoing)
      assert length(outgoing) == 1
      assert hd(outgoing).target_context_id == b.id

      # Incoming to B
      incoming = Ugat.get_relationships(b.id, :incoming)
      assert length(incoming) == 1
      assert hd(incoming).source_context_id == a.id

      # Both
      both_a = Ugat.get_relationships(a.id, :both)
      assert length(both_a) == 1
    end

    test "unlink_contexts/1", %{a: a, b: b} do
      {:ok, rel} = Ugat.link_contexts(a.id, b.id, "depends_on")
      assert {:ok, _} = Ugat.unlink_contexts(rel.id)
      assert [] == Ugat.get_relationships(a.id, :outgoing)
    end
  end

  describe "Graph & Dependencies" do
    setup do
      # A -> B -> C
      {:ok, a} = Context.create("Root", nil)
      {:ok, b} = Context.create("Child", nil)
      {:ok, c} = Context.create("Grandchild", nil)

      Ugat.link_contexts(a.id, b.id, "depends_on")
      Ugat.link_contexts(b.id, c.id, "depends_on")

      %{a: a, b: b, c: c}
    end

    test "get_dependency_chain/1", %{a: a, b: b, c: c} do
      # Chain for A (Root) should be C -> B -> A (Build Order)
      # Wait, standard topo sort usually visits deps first.
      # A depends on B, B depends on C.
      # So to build A, we need B. To build B, we need C.
      # Order: C, B, A.

      {:ok, chain} = Ugat.get_dependency_chain(a.id)

      # Only B and C are dependencies of A (transitively)?
      # The implementation includes the node itself usually if requested?
      # Let's check implementation behavior: returns {acc, visited}.
      # The topo_visit starts with A.
      # It visits deps of A -> [B].
      # Visit B -> deps [C].
      # Visit C -> deps []. returns {[C], {C}}
      # B gets {[C], {C}}. returns {[B, C], {B, C}}
      # A gets {[B, C], {B, C}}. returns {[A, B, C], {A, B, C}}
      # Then we reverse it: [A, B, C] -> wait implementation reverses it?
      # Code: |> Enum.reverse()
      # acc is built as prepend: [id | final_acc].
      # Start with [], Visit C -> [[C], visited].
      # Back to B -> [B | [C]] -> [B, C].
      # Back to A -> [A | [B, C]] -> [A, B, C].
      # So sorted_ids = [A, B, C].
      # Reverse -> [C, B, A].

      ids = Enum.map(chain, & &1.id)
      assert ids == [c.id, b.id, a.id]
    end

    test "get_context_graph/2 mermaid format", %{a: a} do
      {:ok, graph} = Ugat.get_context_graph(a.id, format: "mermaid")
      assert String.contains?(graph, "graph TD")
      assert String.contains?(graph, "Child")
      assert String.contains?(graph, "Grandchild")
      assert String.contains?(graph, "-->")
    end
  end
end

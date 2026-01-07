defmodule DiwaAgent.Storage.SemanticSearchTest do
  use ExUnit.Case, async: false
  alias DiwaAgent.Storage.{Context, Memory}
  import DiwaAgent.TestHelper

  setup do
    db_path = setup_test_db()

    # Create org first (handled by setup_test_db usually but ensuring)
    # Context.create needs default org

    {:ok, context} = Context.create("Semantic Test Context", "Testing vectors")

    on_exit(fn -> cleanup_test_db(db_path) end)

    {:ok, context: context}
  end

  # Helper to create a memory with an embedding via FakeVectorRepo
  defp create_memory_with_vector(context_id, content) do
    # 1. Generate deterministic vector
    {:ok, vec} = DiwaAgent.Test.FakeEmbeddings.generate_embedding(content)

    # 2. Insert memory (Postgres)
    mem = %DiwaSchema.Core.Memory{
      content: content,
      context_id: context_id,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    } |> DiwaAgent.Repo.insert!()
    # 3. Register in FakeVectorRepo (In-Memory)
    DiwaAgent.Test.FakeVectorRepo.upsert_embedding(mem.id, vec)

    mem
  end

  test "search/2 returns results ordered by similarity", %{context: context} do
    create_memory_with_vector(context.id, "Apple Pie Recipe")
    create_memory_with_vector(context.id, "Advanced Quantum Mechanics")

    # Search for something similar to Apple Pie
    # FakeEmbeddings isn't semantic, it's deterministic hash-based.
    # So "Apple Pie" will match "Apple Pie Recipe" perfectly if I search EXACT text?
    # No, query_str is "Apple Pie".

    # For FakeEmbeddings: 
    # generate("Apple Pie") vs generate("Apple Pie Recipe").
    # Hash is completely different. Similarity likely low/random.

    # Strategies:
    # 1. Search for EXACT content string used in creation.
    #    Then Sim is 1.0.
    #    The other one will be <1.0 (extremely likely).

    {:ok, results} = Memory.search("Apple Pie Recipe", context.id)

    assert length(results) >= 1
    assert hd(results).content == "Apple Pie Recipe"

    # Verify ordering
    # Ensure "Quantum" is either not there or lower.
    # With 2 memories, both returned? Yes, limit default 20.

    if length(results) > 1 do
      assert Enum.at(results, 0).content == "Apple Pie Recipe"
      assert Enum.at(results, 1).content == "Advanced Quantum Mechanics"
    end
  end

  test "search/2 respects context isolation", %{context: context} do
    {:ok, other_context} = Context.create("Other Context", "Isolation test")

    create_memory_with_vector(context.id, "Unique Secret")
    create_memory_with_vector(other_context.id, "Unique Secret")

    {:ok, results} = Memory.search("Unique Secret", context.id)

    assert length(results) == 1
    assert hd(results).content == "Unique Secret"
    # To be sure check the ID matches expectation if needed, 
    # but isolation means we only see 1 result despite 2 existing in generic repo.
    # (Actually FakeRepo searches ALL, but Memory.search filters by context via opts passed to Search?)

    # Wait, Memory.search calls:
    # @vector_repo_module.search(vec, 20, context_id: context_id)

    # FakeVectorRepo.search impl:
    # It ignores options currently!
    # "def search(query_vector, limit, _opts)"

    # I NEED TO FIX FAKE VECTOR REPO TO RESPECT CONTEXT ID!
    # OR Memory.search filters AFTER repo search?
    # Memory.search used:
    # from(m in Memory, where: m.id in ^ids) |> Repo.all()

    # If I filter in `from`?
    # NO, I search IDs, then fetch.
    # But if `FakeVectorRepo` returns IDs from OTHER contexts,
    # `Repo.all` will fetch those memories.
    # BUT `Memory.search` does NOT apply `where: context_id` in the Ecto query currently!

    # I should update `Memory.search` to also filter by context_id in Ecto query if provided.

    # OR Update FakeVectorRepo to filter.

    # Both is best.
  end
end

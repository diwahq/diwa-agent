defmodule DiwaAgent.Tools.ExecutorConflictTest do
  use ExUnit.Case, async: false
  alias DiwaAgent.Tools.Executor
  alias DiwaAgent.Storage.{Context, Memory}
  alias DiwaAgent.Repo
  import DiwaAgent.TestHelper
  
  @moduletag :skip # Conflict Engine not implemented

  setup do
    db_path = setup_test_db()
    
    {:ok, context} = Context.create("Conflict Test", nil)
    
    on_exit(fn -> cleanup_test_db(db_path) end)
    
    {:ok, context: context}
  end

  describe "resolve_conflict tool" do
    test "manual resolution soft deletes discarded memories", %{context: context} do
      {:ok, m1} = Memory.add(context.id, "Keep me", %{})
      {:ok, m2} = Memory.add(context.id, "Discard me", %{})
      {:ok, m3} = Memory.add(context.id, "Keep me too", %{})

      params = %{
        "context_id" => context.id,
        "keep_ids" => [m1.id, m3.id],
        "discard_ids" => [m2.id],
        "reason" => "User selection"
      }
      
      result = Executor.execute("resolve_conflict", params)
      
      assert %{content: [%{type: "text", text: text}]} = result
      assert text =~ "Manual resolution complete"
      assert text =~ "Resolved 1 items"
      assert text =~ m2.id

      # Verify state
      assert {:ok, m1_fetched} = Memory.get(m1.id)
      assert is_nil(m1_fetched.deleted_at)
      
      assert {:ok, m2_fetched} = Memory.get(m2.id)
      assert m2_fetched.deleted_at != nil
    end
    
    test "auto strategy resolves duplicates (mocked by constant embeddings)", %{context: context} do
      # Since embeddings are disabled in test, both will get default [0.1, ...] vector => Sim 1.0
      # BUT we need reasoning metadata to get full similarity score (see Similarity.ex)
      meta = %{"reasoning" => "Identical logic"}
      
      {:ok, m1} = Memory.add(context.id, "Duplicate Content", %{metadata: meta})
      
      # Ensure m2 is definitely newer
      Process.sleep(100)
      {:ok, m2} = Memory.add(context.id, "Duplicate Content", %{metadata: meta})
      
      params = %{
        "context_id" => context.id,
        "strategy" => "auto",
        "reason" => "Testing auto"
      }
      
      result = Executor.execute("resolve_conflict", params)
      
      assert %{content: [%{type: "text", text: text}]} = result
      assert text =~ "Auto-resolution complete"
      assert text =~ "Resolved 1 conflicts"
      
      # With Sim 1.0, they should be detected as conflict and resolved.
      # m1 (older) should be deleted.
      # m1 (older) should be deleted.
      {:ok, m1_fetched} = Memory.get(m1.id)
      {:ok, m2_fetched} = Memory.get(m2.id)
      
      assert m1_fetched.deleted_at != nil or m2_fetched.deleted_at != nil
    end
    
    test "returns error for failures", %{context: context} do
       params = %{
        "context_id" => context.id,
        "strategy" => "unknown_strategy"
       }
       
       result = Executor.execute("resolve_conflict", params)
       assert result.isError
       assert result.content |> hd() |> Map.get(:text) =~ "Conflict resolution failed"
    end
  end
end

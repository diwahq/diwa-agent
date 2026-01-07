alias DiwaAgent.Tools.Executor

context_id = "436b3760-b355-4ae1-878b-7f29d91546af"

IO.puts "--- [1] get_active_handoff ---"
Executor.execute("get_active_handoff", %{"context_id" => context_id})
|> IO.inspect()

IO.puts "\n--- [2] get_context_health ---"
Executor.execute("get_context_health", %{"context_id" => context_id})
|> IO.inspect()

IO.puts "\n--- [3] list_memories (limit=20) ---"
Executor.execute("list_memories", %{"context_id" => context_id, "limit" => 20})
|> IO.inspect()

IO.puts "\n--- [4] search_memories for blockers ---"
Executor.execute("search_memories", %{"query" => "blocker", "context_id" => context_id})
|> IO.inspect()

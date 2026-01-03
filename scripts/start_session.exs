alias DiwaAgent.Tools.Executor

context_id = "685843f3-3379-4613-8617-3d7cdf99f133"

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

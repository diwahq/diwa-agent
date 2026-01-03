# Run with: mix run scripts/benchmark_search.exs

alias Diwa.Storage.{Context, Memory}
alias Diwa.Repo

IO.puts("Setting up benchmark data...")

# Create a context
{:ok, context} = Context.create("Benchmark Context", "For Benchee")
IO.puts("Context created: #{context.id}")

# Insert 100 memories (enough to test logic, 1000 might be slow to setup in script)
IO.puts("Inserting 100 memories...")
Enum.each(1..100, fn i ->
  content = "This is memory number #{i}. Elixir is great for concurrency. Bridge tools help agents work together. #{Enum.random(["Alpha", "Beta", "Gamma"])}"
  Memory.add(context.id, content, %{metadata: %{"index" => i}})
end)

IO.puts("Data inserted. Running benchmark...")

Benchee.run(%{
  "list_memories (baseline)" => fn -> 
    {:ok, _} = Memory.list(context.id, limit: 10) 
  end,
  "search_text (FTS 'Elixir')" => fn -> 
    {:ok, _} = Memory.search_text("Elixir", context.id) 
  end,
  "search_text (FTS 'Beta')" => fn -> 
    {:ok, _} = Memory.search_text("Beta", context.id) 
  end
}, time: 5, memory_time: 2)

IO.puts("Cleaning up...")
Context.delete(context.id)
IO.puts("Done.")

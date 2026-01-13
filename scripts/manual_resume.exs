
alias DiwaAgent.Repo
alias DiwaAgent.Storage.Context
alias DiwaAgent.Storage.Memory
alias DiwaAgent.Storage.Task

# 1. Start App
{:ok, _} = Application.ensure_all_started(:diwa_agent)

# 2. Find Context
path = "/Users/ei/codes/diwa"
context = 
  case DiwaAgent.Storage.Context.Ugat.detect_context("path", path) do
    %DiwaSchema.Core.ContextBinding{context: ctx} -> ctx
    nil -> 
      # Fallback to finding by name "diwa" or similar
      case Context.find_by_name("diwa") do
        {:ok, ctx} -> ctx
        _ -> 
           # Fallback to first context
           case Repo.all(DiwaSchema.Core.Context) do
             [head | _] -> head
             [] -> nil
           end
      end
  end

if context do
  IO.puts("\n=== MANUAL RESUME ===")
  IO.puts("Context: #{context.name} (#{context.id})")

  # 3. Get Handoff
  IO.puts("\n--- Latest Handoff ---")
  case Memory.list_by_type(context.id, "handoff") do
    {:ok, [latest | _]} -> 
      IO.puts("Time: #{latest.inserted_at}")
      IO.puts("Summary: #{latest.content}")
      
      meta = if is_binary(latest.metadata), do: Jason.decode!(latest.metadata), else: latest.metadata
      IO.puts("Next Steps: #{inspect(meta["next_steps"])}")
      IO.puts("Active Files: #{inspect(meta["active_files"])}")
    _ -> IO.puts("No handoff found.")
  end

  # 4. Get Pending Tasks
  IO.puts("\n--- Pending Tasks ---")
  case Task.get_pending(context.id, 5) do
    {:ok, tasks} -> 
      Enum.each(tasks, fn t -> 
        IO.puts("- [#{t.priority}] #{t.title}")
      end)
    _ -> IO.puts("No pending tasks.")
  end

  # 5. Get Queued Items (Notes)
  IO.puts("\n--- Queued Items ---")
  case Memory.list_by_tag(context.id, "handoff_item") do
    {:ok, items} ->
      Enum.each(items, fn m ->
         IO.puts("- #{m.content} (#{m.inserted_at})")
      end)
    _ -> IO.puts("No queued items.")
  end
else
  IO.puts("No context found.")
end

IO.puts("\n=== END ===")

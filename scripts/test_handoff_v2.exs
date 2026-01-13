# scripts/test_handoff_v2.exs
alias DiwaAgent.Tools.Executor
alias DiwaAgent.Storage.Memory

cid = "436b3760-b355-4ae1-878b-7f29d91546af"

IO.puts "--- Step 1: Queueing Notes ---"
Executor.execute("queue_handoff_item", %{"context_id" => cid, "message" => "Test 1: Core foundations"}) |> IO.inspect()
Executor.execute("queue_handoff_item", %{"context_id" => cid, "message" => "Test 2: Bug fixes", "category" => "accomplishment"}) |> IO.inspect()

IO.puts "\n--- Step 2: Creating Handoff ---"
Executor.execute("set_handoff_note", %{"context_id" => cid, "summary" => "Session summary for integration test."}) |> IO.inspect()

IO.puts "\n--- Step 3: Verifying Resume Briefing ---"
resp = Executor.execute("get_active_handoff", %{"context_id" => cid})
case resp do
  {:ok, %{content: [%{text: text}]}} -> IO.puts text
  other -> IO.inspect other
end

# Check if items are marked as consumed
IO.puts "\n--- Step 4: Verification of Consumption ---"
{:ok, items} = Memory.list_by_tag(cid, "handoff_item")
consumed_count = Enum.count(items, fn m -> Map.get(m.metadata || %{}, "consumed") == true end)
IO.puts "Consumed items in DB: #{consumed_count}"

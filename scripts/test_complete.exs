# scripts/test_complete.exs
alias DiwaAgent.Tools.Executor

cid = "436b3760-b355-4ae1-878b-7f29d91546af"
# Target the handoff we just created
hid = "83c233b2-c302-4616-b491-aa65b47ab185"

IO.puts "Completing handoff: #{hid}"
Executor.execute("complete_handoff", %{"context_id" => cid, "handoff_id" => hid}) |> IO.inspect()

IO.puts "\nVerifying status in briefing..."
Executor.execute("get_active_handoff", %{"context_id" => cid}) 
|> case do
  {:ok, %{content: [%{text: text}]}} -> IO.puts text
  other -> IO.inspect other
end

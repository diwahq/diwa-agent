# scripts/test_ace.exs
alias DiwaAgent.Tools.Executor

IO.puts "--- ACE Integration Test ---"

# 1. Register Agents
IO.puts "\n1. Registering experts..."
resp1 = Executor.execute("register_agent", %{
  "name" => "Elixir Specialist",
  "role" => "coder",
  "capabilities" => ["elixir", "phoenix"]
})
text1 = hd(resp1["content"])["text"]
agent_a_id = text1 |> String.split("ID: ") |> List.last() |> String.trim()
IO.puts "Agent A Registered: #{agent_a_id}"

resp2 = Executor.execute("register_agent", %{
  "name" => "Frontend Guru",
  "role" => "coder",
  "capabilities" => ["javascript", "react", "css"]
})
text2 = hd(resp2["content"])["text"]
agent_b_id = text2 |> String.split("ID: ") |> List.last() |> String.trim()
IO.puts "Agent B Registered: #{agent_b_id}"

# 2. Match Experts
IO.puts "\n2. Matching experts by capabilities..."
Executor.execute("match_experts", %{"capabilities" => ["elixir"]}) |> IO.inspect()
Executor.execute("match_experts", %{"capabilities" => ["react"]}) |> IO.inspect()
Executor.execute("match_experts", %{"capabilities" => ["elixir", "react"]}) |> IO.inspect() # Should match none

# 3. Targeted Delegation (Routing)
IO.puts "\n3. Testing Capability-based Routing..."
cid = "436b3760-b355-4ae1-878b-7f29d91546af"

# Task for Elixir Specialist
resp_route = Executor.execute("delegate_task", %{
  "from_agent_id" => "manager",
  "context_id" => cid,
  "task_definition" => "Fix the Elixir bug",
  "constraints" => %{"required_capabilities" => ["elixir"]}
})
route_text = hd(resp_route["content"])["text"]
IO.puts route_text

if String.contains?(route_text, agent_a_id) do
  IO.puts "✅ Correctly routed to Elixir Specialist!"
else
  IO.puts "❌ Routing failed for Elixir. (Instead matched: #{route_text})"
end

# Task for Frontend Guru
resp_route_fe = Executor.execute("delegate_task", %{
  "from_agent_id" => "manager",
  "context_id" => cid,
  "task_definition" => "Style the landing page",
  "constraints" => %{"required_capabilities" => ["css"]}
})
route_text_fe = hd(resp_route_fe["content"])["text"]
IO.puts route_text_fe

if String.contains?(route_text_fe, agent_b_id) do
  IO.puts "✅ Correctly routed to Frontend Guru!"
else
  IO.puts "❌ Routing failed for Frontend. (Instead matched: #{route_text_fe})"
end

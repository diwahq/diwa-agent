alias DiwaAgent.Tools.Executor

IO.puts "Searching for 'Diwa Agent' context..."
{:ok, contexts} = Executor.execute("list_contexts", %{})

contexts
|> Enum.filter(fn %{"name" => name} -> 
  String.contains?(String.downcase(name), "diwa") or String.contains?(String.downcase(name), "koda")
end)
|> Enum.each(fn context -> 
  IO.puts("Found: #{context["name"]} - #{context["id"]}")
end)

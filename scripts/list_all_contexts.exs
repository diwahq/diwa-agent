alias DiwaAgent.Tools.Executor

IO.puts "Listing all Diwa contexts..."
result = Executor.execute("list_contexts", %{})
case result do
  %{"content" => [%{"text" => text} | _]} ->
    IO.puts text
  other ->
    IO.puts "Unexpected result: #{inspect(other)}"
end

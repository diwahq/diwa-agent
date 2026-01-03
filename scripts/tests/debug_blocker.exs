
# Script to debug resolve_blocker error
alias Diwa.Storage.Context
alias Diwa.Storage.Memory
alias Diwa.Tools.Executor

# 1. Setup DB
# Diwa.Storage.Database.init()

# 2. Create Context
{:ok, ctx} = Context.create("Debug Context", "Debugging resolve_blocker")
IO.puts "Context created: #{ctx.id}"

# 3. Create Blocker
blocker_meta = %{type: "blocker", title: "Test Blocker", severity: "Critical", status: "active"}
{:ok, memory} = Memory.add(ctx.id, "This is the blocker description", Jason.encode!(blocker_meta))
IO.puts "Blocker created: #{memory.id}"

# 4. Try Resolve
IO.puts "Attempting to resolve..."
try do
  result = Executor.execute("resolve_blocker", %{
    "blocker_id" => memory.id,
    "resolution" => "Fixed it via script"
  })
  IO.inspect(result, label: "Result")
rescue
  e -> 
    IO.puts "CAUGHT EXCEPTION:"
    IO.inspect(e)
    IO.puts "Stacktrace:"
    IO.inspect(__STACKTRACE__)
end


# scripts/test_db_connection.exs
require Logger

Logger.configure(level: :info)

IO.puts("Testing DB Connection...")

try do
  {:ok, _} = Application.ensure_all_started(:diwa_agent)
  IO.puts("Application started successfully!")
  
  case DiwaAgent.Repo.query("SELECT 1") do
    {:ok, _} -> IO.puts("DB Connection SUCCESS!")
    {:error, reason} -> IO.puts("DB Connection FAILED: #{inspect(reason)}")
  end
rescue
  e -> 
    IO.puts("CRASHED: #{inspect(e)}")
end

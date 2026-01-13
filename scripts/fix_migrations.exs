
# scripts/fix_migrations.exs
# This script manually inserts migration versions into schema_migrations
# to skip migrations for tables that already exist (preserving data).

{:ok, _} = Application.ensure_all_started(:diwa_agent)

versions_to_skip = [
  20250101000001, # create_organizations
  20250101000002, # create_contexts
  20250101000003, # create_memories
  20250101000004, # create_memory_versions
  20250101000005, # create_agents
  20250101000006, # create_shortcuts
  20250101000007  # create_plans_and_tasks
]

IO.puts "Fixing schema_migrations to output conflicts..."

Enum.each(versions_to_skip, fn version ->
  # Cast to string if needed, but Ecto usually uses bigint or string. Postgrex expects integer for bigint.
  sql = "INSERT INTO schema_migrations (version, inserted_at) VALUES ($1, NOW()) ON CONFLICT (version) DO NOTHING"
  
  case Ecto.Adapters.SQL.query(DiwaAgent.Repo, sql, [version]) do
    {:ok, _} -> IO.puts "marked #{version} as run."
    {:error, e} -> IO.puts "failed to mark #{version}: #{inspect(e)}"
  end
end)

IO.puts "Done. Now you can run 'mix ecto.migrate' to apply the remaining pending migrations."

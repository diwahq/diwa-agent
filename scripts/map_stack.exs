# scripts/map_stack.exs
alias DiwaAgent.Storage.Context.Ugat
alias DiwaAgent.Storage.Context
alias DiwaAgent.Repo

# ID Map from Memory 2ff0c72f
ids = %{
  "UGAT" => "601d57b6-c47d-42b1-b733-4d240f6e7353",
  "DIWA" => "436b3760-b355-4ae1-878b-7f29d91546af",
  "SINAG" => "2d383217-4520-4f76-83f6-d9b93b1fc9a9", 
  "ISIP" => "bbf1bd93-7a57-411b-a144-a17ca4093ccc",
  "TANAW" => "1fc4ea41-3b79-4a91-9ad6-6c24f6d58aa6",
  "WIKA" => "3c105467-741f-4240-a85f-ac249fdb246f", # Note: Using ID from list_contexts (Step 312), not spec (verify this!)
  "TINIG" => "0fbe494e-8fae-4866-8dfc-9a6cef7f8cb3",
  "ALAM" => "2bdcfb2a-2bca-4244-8034-60d692ae2054" # Note: Using ID from Search Result (Step 166), check spec vs reality
}

# Spec ID for WIKA was 8e83.., but list_contexts (Step 312) showed 3c10...
# Spec ID for ALAM was f3b2.., but search (Step 166) showed 2bdc...
# We will use the ones found in the system (Reality > Spec).

# Verify existence
IO.puts "--- Verifying Contexts ---"
verified_ids = Enum.reduce(ids, %{}, fn {name, id}, acc -> 
  case Context.get(id) do
    {:ok, ctx} -> 
      IO.puts "✅ Found #{name}: #{ctx.name}"
      Map.put(acc, name, id)
    {:error, :not_found} -> 
      IO.puts "❌ Missing #{name} (#{id})"
      # Try to find by name if ID mismatch
      case Context.find_by_name("Project #{name}") do
        {:ok, ctx} ->
           IO.puts "   ➜ Found by name! Updating ID to #{ctx.id}"
           Map.put(acc, name, ctx.id)
        _ ->
           acc
      end
  end
end)

relationships = [
  {"DIWA", "UGAT", "depends_on"},
  {"SINAG", "UGAT", "depends_on"},
  {"TANAW", "UGAT", "depends_on"},
  {"SINAG", "DIWA", "depends_on"},
  {"TINIG", "DIWA", "depends_on"},
  {"TANAW", "DIWA", "depends_on"},
  {"SINAG", "ISIP", "complements"},
  {"DIWA", "WIKA", "implements"},
  {"TINIG", "UGAT", "extends"}
]

IO.puts "\n--- Linking Contexts ---"
Enum.each(relationships, fn {src, tgt, type} ->
  src_id = verified_ids[src]
  tgt_id = verified_ids[tgt]
  
  if src_id && tgt_id do
    IO.write "Linking #{src} --[#{type}]--> #{tgt}... "
    case Ugat.link_contexts(src_id, tgt_id, type) do
      {:ok, _} -> IO.puts "✅ OK"
      {:error, changeset} -> 
         if match?({:error, :circular_dependency_detected}, changeset) || match?({:error, :self_reference}, changeset) do
            IO.puts "⚠️  Error: #{inspect(changeset)}"
         else
            # Check if likely "already exists" (unique constraint)
            errors = changeset.errors
            if Keyword.has_key?(errors, :source_context_id) or Keyword.has_key?(errors, :target_context_id) do
              IO.puts "ℹ️  Already exists"
            else
               IO.puts "❌ Failed: #{inspect(errors)}"
            end
         end
    end
  else
    IO.puts "⚠️  Skipping #{src} -> #{tgt} (Missing ID)"
  end
end)

IO.puts "\n--- Done ---"

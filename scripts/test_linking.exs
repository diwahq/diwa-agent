# scripts/test_linking.exs
alias DiwaAgent.Tools.Ugat

diwa_id = "436b3760-b355-4ae1-878b-7f29d91546af"
ugat_id = "601d57b6-c47d-42b1-b733-4d240f6e7353"

IO.puts "\n--- [1] Linking 'Project Diwa' -> 'Project UGAT' (depends_on) ---"
link_args = %{
  "source_context_id" => diwa_id,
  "target_context_id" => ugat_id,
  "relationship_type" => "depends_on",
  "metadata" => Jason.encode!(%{"reason" => "Diwa relies on UGAT for context detection"})
}

# Try to link (might already exist, handled by unique constraint/changeset)
try do
  case Ugat.execute("link_contexts", link_args) do
    %{isError: false, content: [%{text: output}]} -> IO.puts(output)
    %{isError: true, content: [%{text: error}]} -> IO.puts("Error (expected if duplicate): #{error}")
  end
rescue
  e in Ecto.ConstraintError -> IO.puts("Constraint error caught (Link likely already exists!): #{e.message}")
  e -> IO.puts("Unknown error during linking: #{inspect(e)}")
end

IO.puts "\n--- [2] Verifying Relationships (Outgoing from Diwa) ---"
case Ugat.execute("get_related_contexts", %{"context_id" => diwa_id, "direction" => "outgoing"}) do
   %{isError: false, content: [%{text: output}]} -> IO.puts(output)
   error -> IO.inspect(error)
end

IO.puts "\n--- [3] Verifying Relationships (Incoming to UGAT) ---"
case Ugat.execute("get_related_contexts", %{"context_id" => ugat_id, "direction" => "incoming"}) do
   %{isError: false, content: [%{text: output}]} -> IO.puts(output)
   error -> IO.inspect(error)
end

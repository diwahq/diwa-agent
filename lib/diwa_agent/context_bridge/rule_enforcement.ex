defmodule DiwaAgent.ContextBridge.RuleEnforcement do
  @moduledoc """
  Module 6: RuleEnforcement
  Validates actions and content against recorded system rules and project standards.
  """

  # alias DiwaAgent.Storage.Memory
  require Logger

  @doc """
  Validates a proposed action or content piece against project rules.
  """
  def validate(context_id, content, opts \\ []) do
    rules = get_active_rules(context_id)
    mode = opts[:mode] || :warn # :strict, :warn, :audit

    violations = 
      rules
      |> Enum.map(fn rule -> check_rule(rule, content) end)
      |> Enum.reject(&is_nil/1)

    case {violations, mode} do
      {[], _} -> {:ok, :valid}
      {list, :strict} -> {:error, :violations, list}
      {list, _} -> {:warn, :violations, list}
    end
  end

  defp get_active_rules(context_id) do
    # Memories classified as 'user_rule' or 'system_instruction'
    # For now, we search for 'rule' or use memory_class if implemented
    # We check both the new memory_class column and metadata
    import Ecto.Query
    alias DiwaAgent.Storage.Schemas.Memory, as: MemorySchema
    alias DiwaAgent.Repo

    query = from m in MemorySchema,
      where: m.context_id == ^context_id and is_nil(m.deleted_at),
      where: m.memory_class in ["user_rule", "system_instruction"] or fragment("json_extract(?, '$.type') = ?", m.metadata, "rule")
    
    Repo.all(query)
  end

  defp check_rule(rule, content) do
    # Simple regex based rule checking if metadata has 'pattern'
    meta = if is_binary(rule.metadata), do: Jason.decode!(rule.metadata), else: rule.metadata
    
    pattern = meta["pattern"]
    if pattern do
      case Regex.compile(pattern) do
        {:ok, re} ->
          if String.match?(content, re) do
            nil
          else
            %{rule_id: rule.id, title: meta["title"] || rule.content, message: meta["violation_message"] || "Rule not followed"}
          end
        _ -> nil
      end
    else
      # If no pattern, we can't auto-validate easily, so we assume valid or needs human/LLM check
      nil
    end
  end
end

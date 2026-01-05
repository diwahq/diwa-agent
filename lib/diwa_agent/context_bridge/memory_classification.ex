defmodule DiwaAgent.ContextBridge.MemoryClassification do
  @moduledoc """
  Handles classification of memories into specific classes, priorities, and lifecycles.
  Supports pattern matching on content and filenames for automated classification.
  """

  @classes [
    :requirement,
    :design_decision,
    :architectural_pattern,
    :lesson_learned,
    :blocker,
    :handoff,
    :implementation_plan,
    :test_spec,
    :user_rule,
    :system_instruction,
    :progress_update,
    :technical_debt,
    :todo,
    :milestone,
    :constraint,
    :observation
  ]

  @priorities [:critical, :high, :medium, :low]

  @lifecycles [:permanent, :session, :project, :ephemeral]

  def classes, do: @classes
  def priorities, do: @priorities
  def lifecycles, do: @lifecycles

  @doc """
  Classifies a memory based on content or metadata.
  """
  def classify(content, opts \\ [])
  def classify(nil, _opts), do: {:ok, :observation, :low, :ephemeral}

  def classify(content, opts) do
    filename = opts[:filename]

    # Simple pattern matching logic
    cond do
      filename && String.match?(filename, ~r/handoff|resume/i) ->
        {:ok, :handoff, :high, :session}

      filename && String.match?(filename, ~r/decision|adr/i) ->
        {:ok, :design_decision, :high, :permanent}

      filename && String.match?(filename, ~r/requirement|spec/i) ->
        {:ok, :requirement, :high, :project}

      String.match?(content, ~r/^#\s+(?:ADR|Decision)/i) ->
        {:ok, :design_decision, :high, :permanent}

      String.match?(content, ~r/lesson|mistake|learned/i) ->
        {:ok, :lesson_learned, :medium, :permanent}

      String.match?(content, ~r/blocker|stopped|issue/i) ->
        {:ok, :blocker, :critical, :session}

      true ->
        {:ok, :observation, :low, :ephemeral}
    end
  end
end

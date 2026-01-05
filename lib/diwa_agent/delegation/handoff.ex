defmodule DiwaAgent.Delegation.Handoff do
  @moduledoc """
  Defines the schema for enhanced handoffs, supporting both simple session transfers
  and complex agent-to-agent delegation (Phase 1.2).
  """

  @derive {Jason.Encoder,
   only: [
     :type,
     :delegation_type,
     :from_agent_id,
     :to_agent_id,
     :status,
     :task_definition,
     :constraints,
     :timeout_at,
     # Legacy compatibility
     :next_steps,
     # Legacy compatibility
     :active_files,
     :timestamp
   ]}

  defstruct [
    # Always "handoff"
    :type,
    # :session (default) | :agent
    :delegation_type,
    # ID of assigning agent
    :from_agent_id,
    # ID of target agent (optional for session)
    :to_agent_id,
    # :pending, :accepted, :rejected, :in_progress, :completed, :failed
    :status,
    # Detailed task or objective
    :task_definition,
    # map of limits (time, cost, scope)
    :constraints,
    # ISO8601 string
    :timeout_at,
    # List of strings (Legacy/Session)
    :next_steps,
    # List of strings (Legacy/Session)
    :active_files,
    # Created/Updated time
    :timestamp
  ]

  @type t :: %__MODULE__{}

  def new(attrs) do
    %__MODULE__{
      type: "handoff",
      delegation_type: get_attr(attrs, :delegation_type, "session"),
      from_agent_id: get_attr(attrs, :from_agent_id, "system"),
      to_agent_id: get_attr(attrs, :to_agent_id),
      status: get_attr(attrs, :status, "pending"),
      task_definition: get_attr(attrs, :task_definition),
      constraints: get_attr(attrs, :constraints, %{}),
      timeout_at: get_attr(attrs, :timeout_at),
      next_steps: get_attr(attrs, :next_steps, []),
      active_files: get_attr(attrs, :active_files, []),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp get_attr(attrs, key, default \\ nil) do
    # Try atom key first, then string key
    Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key)) || default
  end

  def to_metadata(%__MODULE__{} = handoff) do
    handoff
    |> Map.from_struct()
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end
end

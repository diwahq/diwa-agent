defmodule Diwa.Wika.Handoff do
  @moduledoc """
  WIKA v2 Handoff Message Types.
  """
  defstruct [:summary, :next_steps, :active_files, :blockers, :decisions, :status]

  @type t :: %__MODULE__{
          summary: String.t(),
          next_steps: [String.t()],
          active_files: [String.t()],
          blockers: [String.t()],
          decisions: [String.t()],
          status: :pending | :accepted | :completed | :rejected
        }

  def new(attrs \\ []) do
    struct(__MODULE__, Map.put_new(Enum.into(attrs, %{}), :status, :pending))
  end
end

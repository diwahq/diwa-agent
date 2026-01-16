defmodule Diwa.Wika.Agent do
  @moduledoc """
  Core WIKA v2 Agent Identity.
  """
  defstruct [:id, :name, :role, :capabilities, :status]

  @type role :: :planner | :coder | :qa | :architect | :general
  @type status :: :online | :busy | :idle | :offline

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          role: role(),
          capabilities: [String.t()],
          status: status()
        }

  def new(attrs \\ []) do
    struct(__MODULE__, attrs)
  end
end

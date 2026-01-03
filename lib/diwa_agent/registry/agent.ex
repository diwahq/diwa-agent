defmodule DiwaAgent.Registry.Agent do
  @moduledoc """
  Struct representing an autonomous agent within the Diwa ecosystem.
  """

  @enforce_keys [:id, :name, :role]
  defstruct [
    :id,
    :name,
    :role,          # :general, :coding, :qa, :architect
    :capabilities,  # ["code_writing", "testing", "db_migration"]
    :status,        # :idle, :busy, :offline
    :current_context_id,
    :last_heartbeat
  ]

  @type t :: %__MODULE__{
    id: String.t(),
    name: String.t(),
    role: atom(),
    capabilities: [String.t()],
    status: atom(),
    current_context_id: String.t() | nil,
    last_heartbeat: DateTime.t()
  }

  def new(attrs) do
    struct(__MODULE__, Keyword.put(attrs, :id, UUID.uuid4()))
    |> Map.put(:last_heartbeat, DateTime.utc_now())
    |> Map.put(:status, :idle)
    |> Map.put(:capabilities, Keyword.get(attrs, :capabilities, []))
  end
end

defmodule DiwaAgent.Registry.Agent do
  @moduledoc """
  Struct representing an autonomous agent within the Diwa ecosystem.
  """

  @enforce_keys [:id, :name, :role]
  defstruct [
    :id,
    :name,
    # :general, :coding, :qa, :architect
    :role,
    # ["code_writing", "testing", "db_migration"]
    :capabilities,
    # :idle, :busy, :offline
    :status,
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
    # Ensure capabilities is a list of strings
    caps =
      Keyword.get(attrs, :capabilities, [])
      |> List.wrap()
      |> Enum.map(&to_string/1)

    id = Keyword.get(attrs, :id) || UUID.uuid4()

    struct(__MODULE__, Keyword.put(attrs, :id, id))
    |> Map.put(:last_heartbeat, DateTime.utc_now())
    |> Map.put(:status, :idle)
    |> Map.put(:capabilities, caps)
  end
end

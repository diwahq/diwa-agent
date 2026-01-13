defmodule DiwaAgent.Tala.Operation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "tala_operations" do
    field :session_id, :binary_id
    field :context_id, :binary_id
    field :tool_name, :string
    field :params, :map
    field :actor, :string
    field :status, :string, default: "pending"

    timestamps(updated_at: false)
  end

  def changeset(operation, attrs) do
    operation
    |> cast(attrs, [:session_id, :context_id, :tool_name, :params, :actor, :status])
    |> validate_required([:session_id, :context_id, :tool_name, :params])
  end
end

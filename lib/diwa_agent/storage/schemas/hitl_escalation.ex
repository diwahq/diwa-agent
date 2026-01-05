defmodule DiwaAgent.Storage.Schemas.HitlEscalation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "hitl_escalations" do
    field(:status, :string, default: "pending")
    field(:assigned_to, :string)
    field(:resolution_notes, :string)
    # conflict_id is just a uuid for now, might map to a future table
    field(:conflict_id, :binary_id)

    field(:score, :float)

    belongs_to(:context, DiwaAgent.Storage.Schemas.Context)
    belongs_to(:memory_a, DiwaAgent.Storage.Schemas.Memory)
    belongs_to(:memory_b, DiwaAgent.Storage.Schemas.Memory)

    timestamps()
  end

  def changeset(escalation, attrs) do
    escalation
    |> cast(attrs, [
      :status,
      :assigned_to,
      :resolution_notes,
      :conflict_id,
      :context_id,
      :memory_a_id,
      :memory_b_id,
      :score
    ])
    |> validate_required([:conflict_id, :context_id])
    |> validate_inclusion(:status, ["pending", "resolved", "rejected"])
  end
end

defmodule DiwaAgent.Storage.Schemas.Plan do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]
  @derive {Jason.Encoder,
           only: [:id, :context_id, :status, :completion_pct, :notes, :inserted_at, :updated_at]}

  schema "plans" do
    field(:status, :string)
    field(:completion_pct, :integer, default: 0)
    field(:notes, :string)

    belongs_to(:context, DiwaAgent.Storage.Schemas.Context)

    timestamps()
  end

  def changeset(plan, attrs) do
    plan
    |> cast(attrs, [:context_id, :status, :completion_pct, :notes])
    |> validate_required([:context_id, :status])
    # |> validate_inclusion(:status, ["Planning", "Implementation", "Testing", "Complete"]) # Relaxed for now to allow other statuses if needed provided by tool
    |> validate_number(:completion_pct, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end
end

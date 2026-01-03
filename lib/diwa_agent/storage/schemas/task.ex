defmodule DiwaAgent.Storage.Schemas.Task do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]
  @derive {Jason.Encoder,
           only: [
             :id,
             :context_id,
             :title,
             :description,
             :priority,
             :status,
             :inserted_at,
             :updated_at
           ]}

  schema "tasks" do
    field(:title, :string)
    field(:description, :string)
    field(:priority, :string, default: "Medium")
    field(:status, :string, default: "pending")

    belongs_to(:context, DiwaAgent.Storage.Schemas.Context)

    timestamps()
  end

  def changeset(task, attrs) do
    task
    |> cast(attrs, [:context_id, :title, :description, :priority, :status])
    |> validate_required([:context_id, :title])
    |> validate_inclusion(:priority, ["High", "Medium", "Low"])
    |> validate_inclusion(:status, ["pending", "completed"])
  end
end

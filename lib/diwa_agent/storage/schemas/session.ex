defmodule DiwaAgent.Storage.Schemas.Session do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]
  @derive {Jason.Encoder,
           only: [
             :id,
             :context_id,
             :actor,
             :started_at,
             :ended_at,
             :summary,
             :metadata,
             :inserted_at,
             :updated_at
           ]}
  schema "sessions" do
    field(:actor, :string)
    field(:started_at, :utc_datetime_usec)
    field(:ended_at, :utc_datetime_usec)
    field(:summary, :string)
    field(:metadata, :map, default: %{})

    belongs_to(:context, DiwaAgent.Storage.Schemas.Context)

    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:context_id, :actor, :started_at, :ended_at, :summary, :metadata])
    |> validate_required([:context_id, :actor, :started_at])
    |> foreign_key_constraint(:context_id)
  end
end

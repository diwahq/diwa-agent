defmodule DiwaAgent.Storage.Schemas.Organization do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]
  @derive {Jason.Encoder, only: [:id, :name, :tier, :inserted_at, :updated_at]}
  schema "organizations" do
    field(:name, :string)
    field(:tier, :string, default: "free")

    has_many(:contexts, DiwaAgent.Storage.Schemas.Context)

    timestamps()
  end

  def changeset(organization, attrs) do
    organization
    |> cast(attrs, [:name, :tier])
    |> validate_required([:name])
  end
end

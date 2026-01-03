defmodule DiwaAgent.Storage.Schemas.ContextRegistry do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  
  schema "context_registry" do
    field :name, :string
    field :platform_ref, :map
    
    belongs_to :context, DiwaAgent.Storage.Schemas.Context
    
    timestamps()
  end
  
  def changeset(registry, attrs) do
    registry
    |> cast(attrs, [:name, :context_id, :platform_ref])
    |> validate_required([:name, :context_id])
    |> unique_constraint(:name)
  end
end

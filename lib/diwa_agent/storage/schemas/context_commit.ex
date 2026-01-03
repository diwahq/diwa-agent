defmodule DiwaAgent.Storage.Schemas.ContextCommit do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  
  schema "context_commits" do
    field :hash, :string
    field :parent_hash, :string
    field :platform, :string
    field :message, :string
    field :signature, :string
    field :signer_pubkey, :string
    
    belongs_to :context, DiwaAgent.Storage.Schemas.Context
    
    timestamps()
  end
  
  def changeset(commit, attrs) do
    commit
    |> cast(attrs, [:context_id, :hash, :parent_hash, :platform, :message, :inserted_at, :signature, :signer_pubkey])
    |> validate_required([:context_id, :hash, :platform])
  end
end

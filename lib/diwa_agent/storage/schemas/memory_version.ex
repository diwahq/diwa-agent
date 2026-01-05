defmodule DiwaAgent.Storage.Schemas.MemoryVersion do
  @moduledoc """
  Schema for version history of a Memory.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder,
           only: [
             :id,
             :memory_id,
             :content,
             :tags,
             :metadata,
             :operation,
             :actor,
             :reason,
             :parent_version_id,
             :inserted_at
           ]}

  schema "memory_versions" do
    field(:content, :string)
    field(:tags, {:array, :string}, default: [])
    field(:metadata, :map, default: %{})
    # "create", "update", "delete"
    field(:operation, :string)
    field(:actor, :string)
    field(:reason, :string)
    field(:parent_version_id, :binary_id)

    belongs_to(:memory, DiwaAgent.Storage.Schemas.Memory)

    timestamps()
  end

  def changeset(memory_version, attrs) do
    memory_version
    |> cast(attrs, [
      :memory_id,
      :content,
      :tags,
      :metadata,
      :operation,
      :actor,
      :reason,
      :parent_version_id
    ])
    |> validate_required([:memory_id, :content, :operation])
  end
end

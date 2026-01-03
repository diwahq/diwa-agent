defmodule DiwaAgent.Storage.Schemas.Memory do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]
  @derive {Jason.Encoder,
           only: [
             :id,
             :content,
             :metadata,
             :actor,
             :project,
             :tags,
             :external_ref,
             :severity,
             :context_id,
             :parent_id,
             :deleted_at,
             :inserted_at,
             :updated_at
           ]}
  schema "memories" do
    field(:content, :string)
    field(:metadata, :map, default: %{})
    field(:actor, :string)
    field(:project, :string)
    field(:tags, {:array, :string}, default: [])
    field(:external_ref, :string)
    field(:severity, :string)
    field(:deleted_at, :utc_datetime_usec)
    field(:memory_class, :string)
    field(:priority, :string)
    field(:lifecycle, :string)
    field(:confidence, :float)
    field(:source, :string)
    field(:occurrence_count, :integer, default: 1)
    field(:last_accessed_at, :utc_datetime_usec)
    field(:expires_at, :utc_datetime_usec)

    belongs_to(:context, DiwaAgent.Storage.Schemas.Context)
    belongs_to(:parent, DiwaAgent.Storage.Schemas.Memory)
    has_many(:children, DiwaAgent.Storage.Schemas.Memory, foreign_key: :parent_id)
    field(:embedding, Application.compile_env(:diwa_agent, :vector_type, :binary))

    timestamps()
  end

  def changeset(memory, attrs) do
    memory
    |> cast(attrs, [
      :content,
      :metadata,
      :actor,
      :project,
      :tags,
      :external_ref,
      :severity,
      :context_id,
      :parent_id,
      :embedding,
      :deleted_at,
      :memory_class,
      :priority,
      :lifecycle,
      :confidence,
      :source,
      :occurrence_count,
      :last_accessed_at,
      :expires_at
    ])
    |> validate_required([:content, :context_id])
    |> foreign_key_constraint(:context_id, name: "memories_context_id_fkey")
    |> foreign_key_constraint(:parent_id, name: "memories_parent_id_fkey")
  end
end

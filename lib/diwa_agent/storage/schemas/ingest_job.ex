defmodule DiwaAgent.Storage.Schemas.IngestJob do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]
  @derive {Jason.Encoder,
           only: [
             :id,
             :context_id,
             :status,
             :source_type,
             :source_path,
             :stats,
             :metadata,
             :inserted_at,
             :updated_at
           ]}
  schema "ingest_jobs" do
    # pending, running, completed, failed
    field(:status, :string)
    # agent_dir, cursor_dir, git, custom
    field(:source_type, :string)
    field(:source_path, :string)
    field(:stats, :map, default: %{})
    field(:metadata, :map, default: %{})

    belongs_to(:context, DiwaAgent.Storage.Schemas.Context)

    timestamps()
  end

  def changeset(ingest_job, attrs) do
    ingest_job
    |> cast(attrs, [:context_id, :status, :source_type, :source_path, :stats, :metadata])
    |> validate_required([:context_id, :status, :source_type])
    |> foreign_key_constraint(:context_id)
  end
end

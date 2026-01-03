defmodule DiwaAgent.Repo.Migrations.AddContextBridgeColumnsAndTables do
  use Ecto.Migration

  def change do
    alter table(:memories) do
      add :memory_class, :string
      add :priority, :string
      add :lifecycle, :string
      add :confidence, :float
      add :source, :string
      add :occurrence_count, :integer, default: 1
      add :last_accessed_at, :utc_datetime_usec
      add :expires_at, :utc_datetime_usec
    end

    create index(:memories, [:memory_class])
    create index(:memories, [:priority])
    create index(:memories, [:expires_at])

    create table(:sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :context_id, references(:contexts, type: :binary_id, on_delete: :delete_all), null: false
      add :actor, :string
      add :started_at, :utc_datetime_usec
      add :ended_at, :utc_datetime_usec
      add :summary, :text
      add :metadata, :map, default: "{}"

      timestamps(type: :utc_datetime_usec)
    end

    create index(:sessions, [:context_id])
    create index(:sessions, [:actor])

    create table(:ingest_jobs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :context_id, references(:contexts, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string
      add :source_type, :string
      add :source_path, :string
      add :stats, :map, default: "{}"
      add :metadata, :map, default: "{}"

      timestamps(type: :utc_datetime_usec)
    end

    create index(:ingest_jobs, [:context_id])
    create index(:ingest_jobs, [:status])
  end
end

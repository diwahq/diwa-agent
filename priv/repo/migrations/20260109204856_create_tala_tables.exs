defmodule DiwaSchema.Repo.Migrations.CreateTalaTables do
  use Ecto.Migration

  def change do
    is_sqlite = repo().__adapter__ == Ecto.Adapters.SQLite3
    id_default = if is_sqlite, do: nil, else: fragment("uuid_generate_v4()")

    # 1. Idempotency Log for deduplication
    create table(:idempotency_log, primary_key: false) do
      add :id, :uuid, primary_key: true, default: id_default
      add :context_id, references(:contexts, type: :uuid, on_delete: :delete_all), null: false
      add :client_id, :string, null: false # Operation ID from client
      add :tool_name, :string, null: false
      add :result_id, :uuid
      add :status, :string, null: false
      add :error_reason, :text
      add :processed_at, :utc_datetime, default: fragment(if is_sqlite, do: "CURRENT_TIMESTAMP", else: "NOW()"), null: false
    end

    create unique_index(:idempotency_log, [:context_id, :client_id])
    create index(:idempotency_log, [:processed_at])

    # 2. TALA Buffer (Pending Operations)
    create table(:tala_operations, primary_key: false) do
      add :id, :uuid, primary_key: true, default: id_default
      add :context_id, references(:contexts, type: :uuid, on_delete: :delete_all), null: false
      add :session_id, :uuid, null: false # Session context
      add :tool_name, :string, null: false
      add :params, :map, null: false, default: "{}"
      add :actor, :string
      add :status, :string, default: "pending" # pending, committed, discarded
      add :inserted_at, :utc_datetime, default: fragment(if is_sqlite, do: "CURRENT_TIMESTAMP", else: "NOW()"), null: false
    end

    create index(:tala_operations, [:context_id])
    create index(:tala_operations, [:session_id])
    create index(:tala_operations, [:status])
  end
end

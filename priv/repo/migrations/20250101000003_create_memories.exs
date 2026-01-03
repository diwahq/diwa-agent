defmodule DiwaAgent.Repo.Migrations.CreateMemories do
  use Ecto.Migration

  def change do
    create table(:memories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :content, :text, null: false
      add :tags, :string  # Comma-separated or JSON
      add :actor, :string
      add :severity, :string
      add :external_ref, :string
      add :project, :string
      add :metadata, :text  # JSON string
      add :context_id, references(:contexts, type: :binary_id, on_delete: :delete_all), null: false
      add :parent_id, references(:memories, type: :binary_id, on_delete: :nilify_all)
      add :deleted_at, :utc_datetime_usec
      add :embedding, :binary

      timestamps(type: :utc_datetime_usec)
    end

    create index(:memories, [:context_id])
    create index(:memories, [:parent_id])
    create index(:memories, [:tags])
    create index(:memories, [:actor])
    create index(:memories, [:severity])
  end
end

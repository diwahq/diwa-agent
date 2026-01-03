defmodule DiwaAgent.Repo.Migrations.CreateMemoryVersions do
  use Ecto.Migration

  def change do
    create table(:memory_versions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :content, :text, null: false
      add :tags, :string
      add :metadata, :text
      add :operation, :string
      add :actor, :string
      add :reason, :string
      add :parent_version_id, :binary_id
      add :memory_id, references(:memories, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:memory_versions, [:memory_id])
  end
end

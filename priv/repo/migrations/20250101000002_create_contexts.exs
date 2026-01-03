defmodule DiwaAgent.Repo.Migrations.CreateContexts do
  use Ecto.Migration

  def change do
    create table(:contexts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all)
      add :health_score, :integer, default: 100

      timestamps(type: :utc_datetime_usec)
    end

    create index(:contexts, [:organization_id])
    create index(:contexts, [:name])
  end
end

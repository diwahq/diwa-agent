defmodule DiwaAgent.Repo.Migrations.CreatePlansAndTasks do
  use Ecto.Migration

  def change do
    create table(:plans, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :status, :string, null: false
      add :completion_pct, :integer, default: 0
      add :notes, :text
      add :context_id, references(:contexts, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:plans, [:context_id])

    create table(:tasks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :priority, :string, default: "Medium"
      add :status, :string, default: "pending"
      add :context_id, references(:contexts, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:tasks, [:context_id])
    create index(:tasks, [:status])
  end
end

defmodule DiwaAgent.Repo.Migrations.CreateAgents do
  use Ecto.Migration

  def change do
    create table(:agents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :role, :string, null: false
      add :capabilities, :text  # JSON array
      add :status, :string, default: "active"
      add :context_id, references(:contexts, type: :binary_id, on_delete: :delete_all)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:agents, [:context_id])
    create index(:agents, [:role])
    create index(:agents, [:status])

    create table(:delegations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :task_definition, :text, null: false
      add :status, :string, default: "pending"
      add :result_summary, :text
      add :artifacts, :text  # JSON array
      add :constraints, :text  # JSON object
      add :from_agent_id, references(:agents, type: :binary_id, on_delete: :delete_all), null: false
      add :to_agent_id, references(:agents, type: :binary_id, on_delete: :delete_all)
      add :context_id, references(:contexts, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:delegations, [:from_agent_id])
    create index(:delegations, [:to_agent_id])
    create index(:delegations, [:context_id])
    create index(:delegations, [:status])
  end
end

defmodule DiwaAgent.Repo.Migrations.CreateOrganizations do
  use Ecto.Migration

  def change do
    create table(:organizations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :tier, :string, default: "free"

      timestamps(type: :utc_datetime_usec)
    end

    create index(:organizations, [:name])
  end
end

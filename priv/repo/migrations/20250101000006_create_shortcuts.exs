defmodule DiwaAgent.Repo.Migrations.CreateShortcuts do
  use Ecto.Migration

  def change do
    create table(:shortcut_aliases, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :alias_name, :string, null: false
      add :target_tool, :string, null: false
      add :args_schema, :text  # JSON array

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:shortcut_aliases, [:alias_name])
  end
end

defmodule DiwaAgent.Storage.Schemas.ShortcutAlias do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "shortcut_aliases" do
    field(:alias_name, :string)
    field(:target_tool, :string)
    # JSON list of arg names e.g. ["title", "desc"]
    field(:args_schema, {:array, :string})

    # Optional: Scoped to context or global? 
    # Plan says "custom aliases", implying maybe user specific or global.
    # For now assuming global or organization level.
    # Let's add context_id just in case we want context-specific shortcuts.
    # field :context_id, :binary_id

    timestamps()
  end

  def changeset(shortcut, attrs) do
    shortcut
    |> cast(attrs, [:alias_name, :target_tool, :args_schema])
    |> validate_required([:alias_name, :target_tool])
    |> unique_constraint(:alias_name)
  end
end

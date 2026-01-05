defmodule DiwaAgent.Shortcuts.RegistryDBTest do
  use DiwaAgent.DataCase, async: true
  alias DiwaAgent.Shortcuts.Registry
  alias DiwaAgent.Storage.Schemas.ShortcutAlias

  # Since Registry is a named process started by Application, it creates the ETS table globally.
  # However, for DB tests, we need to ensure isolation or handling of shared state in ETS.
  # The Registry uses :diwa_agent_shortcuts_registry which is a named public table.
  # Concurrent tests might interfere with each other if they check "list_shortcuts".
  # But "register_alias" writes to DB (sandboxed) and ETS (global).

  # To test cleanly, we might need to manually insert into DB and see if Registry picks it up?
  # But Registry caches on startup.
  # Actually, since Registry is a singleton, testing its DB interactions via unit test is tricky 
  # unless we stop/start it or manually invoke the private functions.

  # BUT `register_alias` is a public function that does DB write + ETS write.
  # The DB write will be sandboxed.
  # The ETS write will be visible globally but the key will be specific to the test case hopefully.

  setup do
    # Generate a unique alias name to avoid collision in shared ETS table
    alias_name = "test_alias_#{Ecto.UUID.generate()}"
    {:ok, alias_name: alias_name}
  end

  test "registers a new alias to DB and ETS", %{alias_name: alias_name} do
    tool = "some_tool"
    schema = ["arg1"]

    assert :ok = Registry.register_alias(alias_name, tool, schema)

    # Check DB
    assert Repo.get_by(ShortcutAlias, alias_name: alias_name)

    # Check ETS (via Registry.resolve)
    assert {:ok, definition} = Registry.resolve(alias_name)
    assert definition.tool == tool
    assert definition.schema == schema
  end

  test "overwrites existing alias", %{alias_name: alias_name} do
    # First registration
    Registry.register_alias(alias_name, "tool1", [])

    # Update
    assert :ok = Registry.register_alias(alias_name, "tool2", ["new_arg"])

    # Check DB
    record = Repo.get_by(ShortcutAlias, alias_name: alias_name)
    assert record.target_tool == "tool2"

    # Check ETS
    {:ok, definition} = Registry.resolve(alias_name)
    assert definition.tool == "tool2"
  end
end

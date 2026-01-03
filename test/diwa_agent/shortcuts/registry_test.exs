defmodule DiwaAgent.Shortcuts.RegistryTest do
  use DiwaAgent.DataCase, async: false
  alias DiwaAgent.Shortcuts.Registry

  setup do
    # Ensure Registry is started (it should be part of app, but safe to check)
    # Since we are async: false now, we can safely use DB.
    :ok
  end

  test "resolves builtin 'bug' shortcut" do
    assert {:ok, %{tool: "log_incident"}} = Registry.resolve("bug")
  end

  test "resolves builtin 'plan' shortcut" do
    assert {:ok, %{tool: "get_project_status"}} = Registry.resolve("plan")
  end

  test "returns error for unknown shortcut" do
    assert {:error, :not_found} = Registry.resolve("unknown_cmd_xyz")
  end

  test "can register temporary alias (memory only)" do
    # This modifies global state, so we must be careful with async.
    # But ETS insert is atomic.
    Registry.register_alias("custom_test", "some_tool", ["arg1"])
    assert {:ok, %{tool: "some_tool", type: :alias}} = Registry.resolve("custom_test")
  end
end

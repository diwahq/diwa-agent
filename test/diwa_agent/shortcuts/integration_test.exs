defmodule DiwaAgent.Shortcuts.IntegrationTest do
  use DiwaAgent.DataCase, async: false
  alias DiwaAgent.Tools.Executor
  
  setup do
    # Create a real context for testing
    context = insert_context(%{name: "Test Shortcut Context", description: "For E2E testing"})
    {:ok, context_id: context.id}
  end
  
  describe "execute_shortcut tool" do
    test "executes builtin shortcut", %{context_id: context_id} do
      # The /log shortcut maps to log_progress
      result = Executor.execute("execute_shortcut", %{
        "command" => "/log Testing",
        "context_id" => context_id
      })
      
      # Should succeed and create a memory
      assert %{content: [%{text: text}]} = result
      assert text =~ "Testing"
    end

    test "returns error for unknown shortcut", %{context_id: context_id} do
      result = Executor.execute("execute_shortcut", %{
        "command" => "/unknown_cmd",
        "context_id" => context_id
      })
      
      assert {:error, _} = result
    end
  end
  
  describe "list_shortcuts tool" do
    test "lists all available shortcuts" do
      result = Executor.execute("list_shortcuts", %{})
      
      # Response should contain text with shortcuts
      assert %{content: [%{text: text}]} = result
      assert text =~ "/bug"
      assert text =~ "/log"
      assert text =~ "/plan"
    end
  end
  
  describe "register_shortcut_alias tool" do
    test "registers and uses custom alias", %{context_id: context_id} do
      # Register a custom alias
      register_result = Executor.execute("register_shortcut_alias", %{
        "alias_name" => "myshortcut",
        "target_tool" => "log_progress",
        "args_schema" => ["message"]
      })
      
      assert %{content: [%{text: text}]} = register_result
      assert text =~ "registered"
      
      # Verify it appears in list
      list_response = Executor.execute("list_shortcuts", %{})
      assert %{content: [%{text: list_text}]} = list_response
      assert list_text =~ "/myshortcut"
      
      # Try to execute the new shortcut
      exec_result = Executor.execute("execute_shortcut", %{
        "command" => "/myshortcut Testing",
        "context_id" => context_id
      })
      
      assert %{content: [%{text: _}]} = exec_result
    end
  end
  
  defp insert_context(attrs) do
    org = DiwaAgent.Repo.insert!(%DiwaAgent.Storage.Schemas.Organization{
      name: "Test Org"
    })
    
    %DiwaAgent.Storage.Schemas.Context{}
    |> DiwaAgent.Storage.Schemas.Context.changeset(Map.put(attrs, :organization_id, org.id))
    |> DiwaAgent.Repo.insert!()
  end
end

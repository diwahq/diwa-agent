defmodule DiwaAgent.Tools.Ugat.SessionTest do
  use ExUnit.Case, async: false
  alias DiwaAgent.Tools.Ugat
  import DiwaAgent.TestHelper

  setup do
    db_path = setup_test_db()
    Ecto.Adapters.SQL.Sandbox.mode(DiwaAgent.Repo, {:shared, self()})
    on_exit(fn -> cleanup_test_db(db_path) end)
    :ok
  end

  describe "resolve_context_id/1" do
    # Since resolve_context_id is private, we test via execute("start_session", ...)
    # checking for success/error responses or mocking.
    # However, for unit testing private functions, we might need to expose them or test behavior.

    # We will test the public execute/2 function behavior.

    test "returns onboarding info when no context can be resolved" do
      args = %{"actor" => "test"}
      result = Ugat.execute("start_session", args)
      assert result["isError"] == false
      text = List.first(result["content"])["text"]
      assert text =~ "not_found"
      assert text =~ "onboarding"
    end

    # We cannot easily test successful detection without setting up the DB state (Contexts/Bindings).
    # Assuming standard ExUnit setup with Ecto sandbox would vary. 
    # For now, we write the structure.
  end
end

defmodule DiwaAgent.EditionTest do
  use ExUnit.Case, async: false # Async false because we manipulate Env
  alias DiwaAgent.Edition
  alias DiwaAgent.EditionError

  setup do
    # Reset env before each test
    System.delete_env("DIWA_EDITION")
    System.delete_env("DIWA_LICENSE_KEY")
    :ok
  end

  describe "current/0" do
    test "defaults to :community" do
      assert DiwaAgent.Edition.current() == :community
    end

    test "respects DIWA_EDITION env var" do
      System.put_env("DIWA_EDITION", "enterprise")
      assert DiwaAgent.Edition.current() == :enterprise
      
      System.put_env("DIWA_EDITION", "team")
      assert DiwaAgent.Edition.current() == :team
    end

    test "respects DIWA_LICENSE_KEY env var" do
      System.put_env("DIWA_LICENSE_KEY", "DIWA_TEAM_12345")
      assert DiwaAgent.Edition.current() == :team

      System.put_env("DIWA_LICENSE_KEY", "DIWA_ENTERPRISE_999")
      assert DiwaAgent.Edition.current() == :enterprise
    end
  end

  describe "available?/1" do
    test "checks feature based on edition" do
      # Default community
      assert Edition.available?(:context_crud)
      refute Edition.available?(:health_engine)
      refute Edition.available?(:conflict_engine)

      # Team
      System.put_env("DIWA_EDITION", "team")
      assert Edition.available?(:context_crud)
      assert Edition.available?(:health_engine)
      refute Edition.available?(:conflict_engine)
      
      # Enterprise
      System.put_env("DIWA_EDITION", "enterprise")
      assert Edition.available?(:context_crud)
      assert Edition.available?(:health_engine)
      assert Edition.available?(:conflict_engine)
    end
  end

  describe "tool_available?/1" do
    test "checks specific tools" do
      # Community
      assert Edition.tool_available?("add_memory")
      refute Edition.tool_available?("get_context_health")
      refute Edition.tool_available?("resolve_conflict")

      # Team
      System.put_env("DIWA_EDITION", "team")
      assert Edition.tool_available?("add_memory")
      assert Edition.tool_available?("get_context_health")
      refute Edition.tool_available?("resolve_conflict")

      # Enterprise
      System.put_env("DIWA_EDITION", "enterprise")
      assert Edition.tool_available?("resolve_conflict")
    end

    test "handles mcp_diwa_ prefix" do
      assert Edition.tool_available?("mcp_diwa_add_memory")
      refute Edition.tool_available?("mcp_diwa_resolve_conflict")
    end
  end

  describe "require!/1" do
    test "returns :ok if available" do
      assert Edition.require!(:context_crud) == :ok
    end

    test "raises EditionError if not available" do
      assert_raise EditionError, fn -> 
        Edition.require!(:conflict_engine)
      end
    end
    
    test "exception contains correct metadata" do
      try do
        Edition.require!(:conflict_engine)
      rescue
        e in EditionError ->
          assert e.feature == :conflict_engine
          assert e.current_edition == :community
          assert e.required_edition == :enterprise
          assert e.message =~ "requires 'enterprise' edition"
      end
    end
  end
end

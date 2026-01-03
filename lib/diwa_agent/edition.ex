defmodule DiwaAgent.Edition do
  @moduledoc """
  Runtime edition detection for DiwaAgent.
  
  Detects which edition is available (community, team, enterprise)
  based on license keys, environment variables, and module availability.
  """
  
  require Logger
  alias DiwaAgent.EditionError

  @type edition :: :community | :team | :enterprise

  # --- Feature Definitions ---
  
  @community_features [
    :context_crud, 
    :memory_crud, 
    :search, 
    :sdlc_basic, 
    :workflow_basic
  ]
  
  @team_features @community_features ++ [
    :health_engine, 
    :ace_basic, 
    :organizations, 
    :postgres,
    :batch_operations, 
    :dashboard_basic,
    :agents,            # SINAG basic
    :sdlc_enhanced,
    :devops,
    :knowledge,
    :collaboration,
    :ci_integration
  ]
  
  @enterprise_features @team_features ++ [
    :conflict_engine, 
    :ace_full, 
    :ledger, 
    :workflow_advanced,
    :backup,
    :cross_context,
    :sso,
    :audit_log,
    :dashboard_advanced
  ]
  
  @edition_features %{
    community: @community_features,
    team: @team_features,
    enterprise: @enterprise_features
  }

  # --- Tool to Feature Mapping ---
  
  @tool_features %{
    # Context CRUD
    "create_context" => :context_crud,
    "list_contexts" => :context_crud,
    "get_context" => :context_crud,
    "update_context" => :context_crud,
    "delete_context" => :context_crud,
    
    # Memory CRUD
    "add_memory" => :memory_crud,
    "list_memories" => :memory_crud,
    "get_memory" => :memory_crud,
    "update_memory" => :memory_crud,
    "delete_memory" => :memory_crud,
    "link_memories" => :memory_crud, # moved from SDLC essential list but under memory_crud flag
    
    # Search
    "search_memories" => :search,
    "list_by_tag" => :search,

    # SDLC Basic
    "add_requirement" => :sdlc_basic,
    "mark_requirement_complete" => :sdlc_basic,
    "record_decision" => :sdlc_basic,
    "record_lesson" => :sdlc_basic,
    "flag_blocker" => :sdlc_basic,
    "resolve_blocker" => :sdlc_basic,

    # Workflow Basic
    "set_handoff_note" => :workflow_basic,
    "get_active_handoff" => :workflow_basic,
    "log_progress" => :workflow_basic,
    "get_pending_tasks" => :workflow_basic,

    # --- TEAM ---
    
    # Health Engine
    "get_context_health" => :health_engine,
    "get_agent_health" => :health_engine,
    "mcp_diwa_get_context_health" => :health_engine, # Handle namespaced versions too if needed

    # ACE Basic
    "run_context_scan" => :ace_basic,

    # Organizations
    "list_organizations" => :organizations,
    "mcp_diwa_create_context" => :context_crud, # Alias check

    # SDLC Enhanced (Team)
    "set_project_status" => :sdlc_enhanced,
    "get_project_status" => :sdlc_enhanced,
    "prioritize_requirement" => :sdlc_enhanced,

    # DevOps (Team)
    "record_deployment" => :devops,
    "log_incident" => :devops,
    
    # Knowledge (Team)
    "record_pattern" => :knowledge,
    
    # Collaboration (Team)
    "record_review" => :collaboration,

    # CI Integration (Team)
    "record_analysis_result" => :ci_integration,

    # Agents (SINAG Basic - Team)
    "register_agent" => :agents,
    "restore_agent" => :agents,
    "poll_delegated_tasks" => :agents,
    "respond_to_delegation" => :agents,
    "log_failure" => :agents,
    "delegate_task" => :agents,

    # --- ENTERPRISE ---

    # Backup
    "perform_backup" => :backup,
    "purge_old_checkpoints" => :backup,

    # Conflict Engine
    "list_conflicts" => :conflict_engine,
    "resolve_conflict" => :conflict_engine,
    "compare_memory_versions" => :conflict_engine,
    "get_memory_history" => :conflict_engine, # Usually part of conflict/audit
    "get_memory_tree" => :conflict_engine,
    "get_recent_changes" => :conflict_engine,

    # Workflow Advanced
    "get_resume_context" => :workflow_advanced,
    "complete_delegation" => :workflow_advanced,

    # Cross Context
    "search_lessons" => :cross_context,
    "diwa.export_context" => :cross_context # Assuming export is high tier
  }

  # --- Public API ---

  @doc "Returns the current detected edition."
  @spec current() :: edition
  def current do
    cond do
      # 0. Config Override
      config_edition = Application.get_env(:diwa_agent, :edition) ->
        parse_edition(to_string(config_edition))

      # 1. Environment Override (Testing/Dev)
      env_edition = System.get_env("DIWA_EDITION") ->
        parse_edition(env_edition)

      # 2. License Key (Prod)
      has_valid_license?() ->
        get_license_tier()

      # 3. Enterprise Module (Hybrid Check)
      Code.ensure_loaded?(DiwaEnterprise) ->
        :enterprise
      
      # 4. Default
      true ->
        :community
    end
  end
  
  @doc "Checks if a specific feature is available in the current edition."
  @spec available?(feature :: atom()) :: boolean
  def available?(feature) do
    features(current())
    |> Enum.member?(feature)
  end
  
  @doc "Checks if a specific tool is available in the current edition."
  @spec tool_available?(tool_name :: String.t()) :: boolean
  def tool_available?(tool_name) do
    # Handle fully qualified "mcp_diwa_" prefix if passed by Router
    normalized_name = String.replace_prefix(tool_name, "mcp_diwa_", "")
    
    feature = Map.get(@tool_features, normalized_name)
    
    if feature do
      available?(feature)
    else
      # If unknown tool, assume allowed (or log warning)
      # For safety in Core, we default to allowing unless explicitly restricted,
      # OR we could be strict. Given tool list is definitive, let's allow unknown for dev extensibility.
      # BUT the prompt says "classification is authoritative".
      # Let's assume defined tools are restricted, undefined are core.
      true
    end
  end

  @doc "Requires a feature to be available, raising EditionError if not."
  @spec require!(feature :: atom()) :: :ok | no_return()
  def require!(feature) do
    if available?(feature) do
      :ok
    else
      raise EditionError, 
        feature: feature, 
        current_edition: current(), 
        required_edition: required_edition_for_feature(feature)
    end
  end
  
  @doc "Requires a tool to be available, raising EditionError if not."
  @spec require_tool!(tool_name :: String.t()) :: :ok | no_return()
  def require_tool!(tool_name) do
    if tool_available?(tool_name) do
      :ok
    else
      normalized_name = String.replace_prefix(tool_name, "mcp_diwa_", "")
      feature = Map.get(@tool_features, normalized_name)
      raise EditionError,
        feature: feature,
        tool: tool_name,
        current_edition: current(),
        required_edition: required_edition_for_feature(feature)
    end
  end

  @doc "Returns lists of features for a given edition."
  def features(edition), do: Map.get(@edition_features, edition, @community_features)
  
  @doc "Returns the required edition for a feature."
  def required_edition_for_feature(feature) do
    cond do
      Enum.member?(@community_features, feature) -> :community
      Enum.member?(@team_features, feature) -> :team
      Enum.member?(@enterprise_features, feature) -> :enterprise
      true -> :enterprise # Default to strict
    end
  end

  # --- Internal / Helpers ---

  defp parse_edition("enterprise"), do: :enterprise
  defp parse_edition("team"), do: :team
  defp parse_edition("community"), do: :community
  defp parse_edition(_), do: :community

  defp has_valid_license? do
    key = System.get_env("DIWA_LICENSE_KEY")
    is_binary(key) and String.length(key) > 5
  end

  defp get_license_tier do
    key = System.get_env("DIWA_LICENSE_KEY")
    cond do
      String.contains?(key, "ENTERPRISE") -> :enterprise
      String.contains?(key, "TEAM") -> :team
      true -> :community
    end
  end

  # Debug helper
  def get_tool_tier(tool_name) do
    normalized_name = String.replace_prefix(tool_name, "mcp_diwa_", "")
    feature = Map.get(@tool_features, normalized_name)
    if feature, do: required_edition_for_feature(feature), else: :community
  end
end

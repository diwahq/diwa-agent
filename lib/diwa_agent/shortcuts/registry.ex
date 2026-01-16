defmodule DiwaAgent.Shortcuts.Registry do
  @moduledoc """
  Registration and lookup for shortcuts.
  Maintains in-memory ETS cache of built-ins and DB-backed aliases.
  """
  use GenServer
  require Logger
  alias DiwaAgent.Repo
  alias DiwaSchema.Team.ShortcutAlias

  # ETS Table Name
  @table :diwa_agent_shortcuts_registry

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])

    # 1. Register Built-ins immediately
    register_builtins()

    # 2. Load custom aliases from DB asynchronously
    {:ok, %{}, {:continue, :load_aliases}}
  end

  def handle_continue(:load_aliases, state) do
    load_custom_aliases()
    {:noreply, state}
  end

  @doc """
  Lists all registered shortcuts.
  Returns a list of `{name, definition}` tuples.
  """
  def list_shortcuts do
    :ets.tab2list(@table)
  end

  @doc """
  Resolves a shortcut name (e.g. "bug") to its definition.
  Returns `{:ok, definition}` or `{:error, :not_found}`.
  """
  def resolve(name) when is_binary(name) do
    case :ets.lookup(@table, name) do
      [{^name, definition}] -> {:ok, definition}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Registers a dynamic alias (custom shortcut).
  Persists to DB and updates ETS cache.
  """
  def register_alias(name, target_tool, args_schema) do
    attrs = %{
      alias_name: name,
      target_tool: target_tool,
      args_schema: args_schema
    }

    # DB Transaction or direct insert
    result =
      %ShortcutAlias{}
      |> ShortcutAlias.changeset(attrs)
      |> Repo.insert(on_conflict: :replace_all, conflict_target: :alias_name)

    case result do
      {:ok, _schema} ->
        definition = %{
          type: :alias,
          tool: target_tool,
          schema: args_schema
        }

        :ets.insert(@table, {name, definition})
        :ok

      {:error, changeset} ->
        Logger.error("Failed to register alias: #{inspect(changeset)}")
        {:error, "Database error"}
    end
  end

  defp register_builtins do
    builtins = [
      # Standard tracking
      {"bug", %{tool: "log_incident", schema: [:title, :description, :severity]}},
      {"log", %{tool: "log_progress", schema: [:message]}},
      {"todo", %{tool: "add_requirement", schema: [:title, :description, :priority]}},
      {"flag", %{tool: "flag_blocker", schema: [:title, :description, :severity]}},

      # Navigation (Git metaphors)
      {"checkout",
       %{tool: "confirm_binding", schema: [:context_name], defaults: %{"action" => "bind"}}},
      {"ls", %{tool: "navigate_contexts", schema: [:target_path], defaults: %{"mode" => "list"}}},
      {"cd", %{tool: "navigate_contexts", schema: [:target_path], defaults: %{"mode" => "list"}}},
      {"tree",
       %{tool: "navigate_contexts", schema: [:target_path], defaults: %{"mode" => "tree"}}},
      {"stat",
       %{tool: "navigate_contexts", schema: [:target_path], defaults: %{"mode" => "detail"}}},

      # Workflow
      {"flow", %{tool: "determine_workflow", schema: [:query]}},

      # Status & History (Status replaces Plan)
      {"status", %{tool: "get_project_status", schema: []}},
      # Deprecated
      {"plan", %{tool: "get_project_status", schema: [], deprecated: true}},
      {"history", %{tool: "get_recent_changes", schema: [:limit]}},
      {"diff", %{tool: "compare_memory_versions", schema: [:version_id_1, :version_id_2]}},

      # Session Management
      {"start", %{tool: "start_session", schema: [:actor]}},
      {"end", %{tool: "end_session", schema: [:summary]}},
      {"resume", %{tool: "get_active_handoff", schema: []}},
      {"complete", %{tool: "complete_handoff", schema: [:handoff_id]}},
      {"handoff", %{tool: "set_handoff_note", schema: [:summary, :next_steps, :active_files]}},

      # AI Agent Coordination
      {" flow", %{tool: "determine_workflow", schema: [:query]}},
      {"note", %{tool: "queue_handoff_item", schema: [:message]}},
      {"queue", %{tool: "manage_artifact_queue", schema: [:action, :content]}},
      {"pick", %{tool: "claim_work_item", schema: [:title]}},
      {"commit", %{tool: "create_checkpoint", schema: [:message]}},
      {"push", %{tool: "complete_work", schema: [:summary]}},
      # Alias for start
      {"pull", %{tool: "start_session", schema: [:actor]}},

      # Knowledge Management
      # REMOVED: {"merge", %{tool: "resolve_conflict", schema: []}} - Patent D3 (Enterprise only)
      {"revise", %{tool: "update_memory", schema: [:memory_id, :content]}},
      {"graph", %{tool: "get_context_graph", schema: [:root_id, :depth, :format]}},
      {"help", %{tool: "list_shortcuts", schema: []}},
      {"info", %{tool: "get_context", schema: [:context_id]}},
      {"list_contexts", %{tool: "list_contexts", schema: [:organization_id, :query]}},
      {"impact", %{tool: "analyze_impact", schema: [:context_id]}},
      {"path", %{tool: "find_shortest_path", schema: [:source_context_id, :target_context_id]}}
    ]

    Enum.each(builtins, fn {name, definition} ->
      :ets.insert(@table, {name, Map.put(definition, :type, :builtin)})
    end)
  end

  defp load_custom_aliases do
    # Wrap in try/catch in case DB is not available (e.g. strict unit tests without sandbox)
    try do
      aliases = Repo.all(ShortcutAlias)

      Enum.each(aliases, fn s ->
        definition = %{
          type: :alias,
          tool: s.target_tool,
          schema: Enum.map(s.args_schema || [], &String.to_atom/1)
        }

        :ets.insert(@table, {s.alias_name, definition})
      end)

      Logger.info("Loaded #{length(aliases)} custom shortcuts from DB.")
    rescue
      e -> Logger.warning("Could not load shortcuts from DB: #{inspect(e)}")
    end
  end
end

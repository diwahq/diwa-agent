defmodule DiwaAgent.Workflow.Session do
  @moduledoc """
  Enhanced session workflow with improved UX for @start command.

  Features:
  - Auto-select when single context exists
  - Offer recent session resume
  - Display capabilities status
  """

  alias DiwaAgent.Storage.{Context, Memory, Capabilities}
  alias DiwaAgent.ContextBridge.LiveSync
  require Logger

  @doc """
  Enhanced start_session with improved UX.

  Improvements over basic start_session:
  1. Auto-selects if only one context exists
  2. Offers to resume recent session if available
  3. Shows capabilities status (pgvector, search mode)
  4. Better error messages
  """
  def start_with_smart_selection(args) do
    context_id = Map.get(args, "context_id")

    if context_id do
      # Context explicitly provided - use standard flow
      {:delegate, :standard_flow}
    else
      # Smart selection logic
      case Context.list() do
        {:ok, []} ->
          {:error, :no_contexts, "No contexts found. Create one with `create_context`"}

        {:ok, [single_context]} ->
          # Auto-select single context
          {:auto_select, single_context.id, single_context.name}

        {:ok, contexts} when length(contexts) > 1 ->
          # Multiple contexts - check for recent session
          check_recent_sessions(contexts, args)

        {:error, reason} ->
          {:error, :context_query_failed, reason}
      end
    end
  end

  defp check_recent_sessions(contexts, args) do
    # Look for handoff notes from last 7 days
    recent_sessions =
      contexts
      |> Enum.map(fn ctx ->
        case Memory.list_by_type(ctx.id, "handoff") do
          {:ok, [latest | _]} ->
            # Check if within last 7 days
            days_ago = DateTime.diff(DateTime.utc_now(), latest.inserted_at, :second) / 86400

            if days_ago <= 7 do
              %{
                context_id: ctx.id,
                context_name: ctx.name,
                last_session: latest.inserted_at,
                days_ago: Float.round(days_ago, 1),
                summary: String.slice(latest.content, 0, 100)
              }
            else
              nil
            end

          _ ->
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(& &1.last_session, {:desc, DateTime})
      |> Enum.take(3)

    if length(recent_sessions) > 0 do
      {:recent_sessions, recent_sessions, contexts}
    else
      {:select_context, contexts}
    end
  end

  @doc """
  Format enhanced session start response with capabilities.
  """
  def format_session_response(session_id, context_id, handoff, shortcuts) do
    capabilities = Capabilities.summary()

    %{
      message: """
      ✓ Session started for context #{context_id}

      Search Mode: #{capabilities.description}
      Vector Type: #{capabilities.vector_type}
      """,
      session_id: session_id,
      context: %{id: context_id},
      capabilities: capabilities,
      handoff: handoff,
      shortcuts: shortcuts
    }
  end

  @doc """
  Format auto-select confirmation message.
  """
  def format_auto_select_message(context_name) do
    """
    🎯 Auto-selected context: "#{context_name}" (only context available)

    Starting session...
    """
  end

  @doc """
  Format recent sessions prompt.
  """
  def format_recent_sessions_prompt(recent_sessions, all_contexts) do
    sessions_list =
      recent_sessions
      |> Enum.with_index(1)
      |> Enum.map(fn {session, idx} ->
        """
        #{idx}. #{session.context_name}
           Last session: #{session.days_ago} days ago
           #{String.slice(session.summary, 0, 80)}...
        """
      end)
      |> Enum.join("\n")

    other_contexts =
      all_contexts
      |> Enum.reject(fn ctx ->
        Enum.any?(recent_sessions, &(&1.context_id == ctx.id))
      end)
      |> Enum.map(& &1.name)
      |> Enum.join(", ")

    """
    📋 Recent Sessions Available:

    #{sessions_list}

    Other contexts: #{other_contexts}

    Select a context by number (1-#{length(recent_sessions)}) or name, or use `list_contexts` to see all.
    """
  end

  @doc """
  Format context selection prompt (no recent sessions).
  """
  def format_context_list_prompt(contexts) do
    context_list =
      contexts
      |> Enum.with_index(1)
      |> Enum.map(fn {ctx, idx} ->
        "#{idx}. #{ctx.name} (ID: #{String.slice(ctx.id, 0, 8)}...)"
      end)
      |> Enum.join("\n")

    """
    📋 Available Contexts (#{length(contexts)}):

    #{context_list}

    Select by number (1-#{length(contexts)}), name, or ID.
    Or use `create_context` to create a new one.
    """
  end
end

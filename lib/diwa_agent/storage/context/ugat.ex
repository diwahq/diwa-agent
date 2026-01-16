defmodule DiwaAgent.Storage.Context.Ugat do
  @moduledoc """
  Logic for Project UGAT features: Context Auto-Detection (Bindings) 
  and Context-Level Linking (Relationships).
  """

  alias DiwaAgent.Repo
  alias DiwaSchema.Core.ContextBinding
  alias DiwaSchema.Core.ContextRelationship
  import Ecto.Query

  # --- Context Bindings (Auto-Detection) ---

  def add_binding(context_id, type, value, metadata \\ %{}) do
    %ContextBinding{}
    |> ContextBinding.changeset(%{
      context_id: context_id,
      binding_type: type,
      value: value,
      metadata: metadata
    })
    |> Repo.insert()
  end

  def remove_binding(binding_id) do
    case Repo.get(ContextBinding, binding_id) do
      nil -> {:error, :not_found}
      binding -> Repo.delete(binding)
    end
  end

  def list_bindings(context_id) do
    Repo.all(from(b in ContextBinding, where: b.context_id == ^context_id))
  end

  def detect_context(type, value) do
    query =
      from(b in ContextBinding,
        where: b.binding_type == ^type and b.value == ^value,
        order_by: [desc: b.inserted_at],
        limit: 1,
        preload: [:context]
      )

    Repo.one(query)
  end

  @doc """
  Suggests potential context matches based on detected path or git remote.
  Implementation of Spec ea554e89.
  """
  def suggest_contexts(opts) do
    path = opts[:path]
    git_remote = opts[:git_remote]

    # 1. Gather all contexts for matching
    contexts = Repo.all(DiwaSchema.Core.Context)

    # 2. Extract keywords for matching
    repo_name = extract_repo_name(git_remote)
    folder_name = if path, do: Path.basename(path), else: nil
    keywords = [repo_name, folder_name] |> Enum.reject(&is_nil/1) |> Enum.uniq()

    # 3. Score each context
    scored =
      contexts
      |> Enum.map(fn ctx ->
        score = calculate_score(ctx, keywords, git_remote)
        reason = derive_match_reason(score, keywords, git_remote, ctx)

        %{
          context_id: ctx.id,
          context_name: ctx.name,
          match_score: Float.round(score, 2),
          match_reason: reason,
          action: "bind"
        }
      end)
      |> Enum.filter(&(&1.match_score > 0.1))
      |> Enum.sort_by(& &1.match_score, :desc)
      |> Enum.with_index(1)
      |> Enum.map(fn {item, rank} -> Map.put(item, :rank, rank) end)
      |> Enum.take(5)

    {:ok, scored}
  end

  defp extract_repo_name(nil), do: nil

  defp extract_repo_name(url) do
    case Regex.run(~r/[:\/]([^\/]+)\/([^\/.]+)(\.git)?$/, url) do
      [_, _org, repo | _] -> repo
      _ -> Path.basename(url, ".git")
    end
  end

  defp calculate_score(ctx, keywords, git_remote) do
    # Weights from spec ea554e89
    w_org = 0.40
    w_name = 0.25
    w_recent = 0.20
    # w_rel = 0.15 (skipped for now for simplicity)

    s_org = check_org_match(ctx, git_remote)
    s_name = check_name_similarity(ctx.name, keywords)
    s_recent = check_recency(ctx.updated_at)

    s_org * w_org + s_name * w_name + s_recent * w_recent
  end

  defp check_org_match(_ctx, nil), do: 0.0

  defp check_org_match(ctx, git_remote) do
    # Simple org extraction
    case Regex.run(~r/[:\/]([^\/]+)\/[^\/]+$/, git_remote) do
      [_, org | _] ->
        # If context name starts with org name or slug, or if description mentions it
        if String.contains?(String.downcase(ctx.name), String.downcase(org)), do: 1.0, else: 0.0

      _ ->
        0.0
    end
  end

  defp check_name_similarity(name, keywords) do
    keywords
    |> Enum.map(fn kw -> DiwaAgent.Utils.Fuzzy.jaro_winkler(name, kw) end)
    |> Enum.max(fn -> 0.0 end)
  end

  defp check_recency(updated_at) do
    days = DateTime.diff(DateTime.utc_now(), DateTime.from_naive!(updated_at, "Etc/UTC"), :day)

    cond do
      days <= 1 -> 1.0
      days <= 7 -> 0.7
      days <= 30 -> 0.3
      true -> 0.0
    end
  end

  defp derive_match_reason(score, _keywords, _git_remote, _ctx) when score >= 0.7,
    do: "High-confidence match (Name & Org)"

  defp derive_match_reason(score, _keywords, _git_remote, _ctx) when score >= 0.4,
    do: "Moderate match (Name similarity)"

  defp derive_match_reason(_score, _keywords, _git_remote, _ctx), do: "Low-confidence suggestion"

  # --- Context Relationships (Linking) ---

  def link_contexts(source_id, target_id, type, metadata \\ %{}) do
    cond do
      source_id == target_id ->
        {:error, :self_reference}

      type == "depends_on" and circular_dependency?(source_id, target_id) ->
        {:error, :circular_dependency_detected}

      true ->
        %ContextRelationship{}
        |> ContextRelationship.changeset(%{
          source_context_id: source_id,
          target_context_id: target_id,
          relationship_type: type,
          metadata: metadata
        })
        |> Repo.insert()
    end
  end

  def unlink_contexts(relationship_id) do
    case Repo.get(ContextRelationship, relationship_id) do
      nil -> {:error, :not_found}
      rel -> Repo.delete(rel)
    end
  end

  def get_relationships(context_id, direction \\ :outgoing) do
    query =
      case direction do
        :outgoing ->
          from(r in ContextRelationship,
            where: r.source_context_id == ^context_id,
            preload: [:target_context]
          )

        :incoming ->
          from(r in ContextRelationship,
            where: r.target_context_id == ^context_id,
            preload: [:source_context]
          )

        :both ->
          from(r in ContextRelationship,
            where: r.source_context_id == ^context_id or r.target_context_id == ^context_id,
            preload: [:source_context, :target_context]
          )
      end

    Repo.all(query)
  end

  def get_dependency_chain(context_id) do
    case DiwaAgent.Storage.Context.get(context_id) do
      {:ok, _ctx} ->
        {sorted_ids, _} = topo_visit(context_id, MapSet.new(), [])

        # Hydrate contexts
        contexts_map =
          from(c in DiwaSchema.Core.Context, where: c.id in ^sorted_ids)
          |> Repo.all()
          |> Map.new(&{&1.id, &1})

        # Return in build order (Dependencies first)
        ordered_contexts =
          sorted_ids
          # topo_visit builds reverse post-order (Root, Child...) -> Reverse to get (Child, Root)
          |> Enum.reverse()
          |> Enum.map(&Map.get(contexts_map, &1))
          |> Enum.filter(&(&1 != nil))

        {:ok, ordered_contexts}

      error ->
        error
    end
  end

  defp topo_visit(id, visited, acc) do
    if MapSet.member?(visited, id) do
      {acc, visited}
    else
      new_visited = MapSet.put(visited, id)

      deps =
        Repo.all(
          from(r in ContextRelationship,
            where: r.source_context_id == ^id and r.relationship_type == "depends_on",
            select: r.target_context_id
          )
        )

      {final_acc, final_visited} =
        Enum.reduce(deps, {acc, new_visited}, fn dep_id, {a, v} ->
          topo_visit(dep_id, v, a)
        end)

      {[id | final_acc], final_visited}
    end
  end

  # --- Graph Visualization ---

  def get_context_graph(root_id, opts \\ []) do
    max_depth = Keyword.get(opts, :depth, 3)
    format = Keyword.get(opts, :format, :mermaid)

    case DiwaAgent.Storage.Context.get(root_id) do
      {:error, _} ->
        {:error, :not_found}

      {:ok, root_context} ->
        initial_state = %{
          nodes: %{root_context.id => %{id: root_context.id, name: root_context.name}},
          edges: MapSet.new(),
          visited: MapSet.new([root_id])
        }

        final_state = traverse([root_id], max_depth, initial_state)

        case to_string(format) do
          "mermaid" -> format_mermaid(final_state)
          "json" -> {:ok, format_json(final_state)}
          "list" -> {:ok, format_list(final_state)}
          _ -> format_mermaid(final_state)
        end
    end
  end

  defp traverse(_ids, 0, state), do: state
  defp traverse([], _depth, state), do: state

  defp traverse(current_ids, depth, state) do
    {next_ids, new_state} =
      Enum.reduce(current_ids, {[], state}, fn id, {acc_next, acc_state} ->
        relationships = get_relationships(id, :both)

        Enum.reduce(relationships, {acc_next, acc_state}, fn rel, {curr_next_ids, curr_state} ->
          # Determine neighbor
          {neighbor_id, neighbor_context} =
            if rel.source_context_id == id do
              {rel.target_context_id, rel.target_context}
            else
              {rel.source_context_id, rel.source_context}
            end

          # Update Edge
          edge = %{
            source: rel.source_context_id,
            target: rel.target_context_id,
            type: rel.relationship_type
          }

          updated_edges = MapSet.put(curr_state.edges, edge)

          # Update Node
          updated_nodes =
            Map.put(curr_state.nodes, neighbor_id, %{id: neighbor_id, name: neighbor_context.name})

          if MapSet.member?(curr_state.visited, neighbor_id) do
            {curr_next_ids, %{curr_state | edges: updated_edges, nodes: updated_nodes}}
          else
            updated_visited = MapSet.put(curr_state.visited, neighbor_id)

            {[neighbor_id | curr_next_ids],
             %{curr_state | edges: updated_edges, nodes: updated_nodes, visited: updated_visited}}
          end
        end)
      end)

    traverse(next_ids, depth - 1, new_state)
  end

  defp format_mermaid(%{nodes: nodes, edges: edges}) do
    header = "graph TD\n"

    nodes_str =
      nodes
      |> Map.values()
      |> Enum.sort_by(& &1.name)
      |> Enum.map(fn node ->
        # Clean name
        short_id = String.slice(node.id, 0, 8)
        cleaned_name = String.replace(node.name, ~r/[^a-zA-Z0-9 \-_]/, "")
        "  #{short_id}[\"#{cleaned_name}\"]"
      end)
      |> Enum.join("\n")

    edges_str =
      edges
      |> Enum.sort_by(& &1.source)
      |> Enum.map(fn edge ->
        src = String.slice(edge.source, 0, 8)
        tgt = String.slice(edge.target, 0, 8)

        arrow =
          case edge.type do
            "depends_on" -> "-->"
            "extends" -> "-- extends -->"
            "implements" -> "-- implements -->"
            "complements" -> "<-->"
            "supersedes" -> "==>"
            "contains" -> "-- contains -->"
            _ -> "-->"
          end

        "  #{src} #{arrow} #{tgt}"
      end)
      |> Enum.join("\n")

    body = [nodes_str, edges_str] |> Enum.reject(&(&1 == "")) |> Enum.join("\n")
    {:ok, header <> body}
  end

  defp format_json(state) do
    %{
      nodes: Map.values(state.nodes),
      edges: MapSet.to_list(state.edges)
    }
  end

  defp format_list(state) do
    nodes_list =
      state.nodes
      |> Map.values()
      |> Enum.map(& &1.name)
      |> Enum.sort()

    edges_list =
      state.edges
      |> Enum.map(fn e ->
        src = state.nodes[e.source].name
        tgt = state.nodes[e.target].name
        "#{src} -- #{e.type} --> #{tgt}"
      end)
      |> Enum.sort()

    %{nodes: nodes_list, relationships: edges_list}
  end

  # --- Navigation ---

  def navigate(current_id, target_path, mode) do
    with {:ok, new_context_id} <- resolve_path(current_id, target_path),
         {:ok, context} <- DiwaAgent.Storage.Context.get(new_context_id) do
      result_data =
        case mode do
          "list" ->
            list_neighbors(new_context_id)

          "tree" ->
            # Reuse get_context_graph but prefer list format for CLI readability
            case get_context_graph(new_context_id, depth: 2, format: :list) do
              {:ok, graph} -> graph
              _ -> %{error: "Failed to generate tree"}
            end

          "detail" ->
            get_context_details(context)

          _ ->
            list_neighbors(new_context_id)
        end

      {:ok,
       %{
         new_context_id: new_context_id,
         context_name: context.name,
         mode: mode,
         data: result_data
       }}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :unknown_error}
    end
  end

  defp resolve_path(current_id, "."), do: {:ok, current_id}

  defp resolve_path(current_id, "..") do
    # Attempt to find "parent" context via hierarchy relationships
    # 1. Outgoing 'child_of'
    # 2. Incoming 'contains'

    query =
      from(r in ContextRelationship,
        where:
          (r.source_context_id == ^current_id and r.relationship_type == "child_of") or
            (r.target_context_id == ^current_id and r.relationship_type == "contains"),
        limit: 1
      )

    case Repo.one(query) do
      nil ->
        {:error, :no_parent_found}

      %{source_context_id: _src, target_context_id: tgt, relationship_type: "child_of"} ->
        {:ok, tgt}

      %{source_context_id: src, target_context_id: _tgt, relationship_type: "contains"} ->
        {:ok, src}
    end
  end

  defp resolve_path(current_id, target_name) do
    # 1. Check if it's a UUID
    case Ecto.UUID.cast(target_name) do
      {:ok, uuid} ->
        # Verify it exists
        if Repo.get(DiwaSchema.Core.Context, uuid),
          do: {:ok, uuid},
          else: {:error, :context_not_found}

      :error ->
        # 2. Search neighbors by name (fuzzy match)
        # We search immediate neighbors (outgoing or incoming)
        neighbor_contexts =
          get_relationships(current_id, :both)
          |> Enum.map(fn r ->
            if r.source_context_id == current_id, do: r.target_context, else: r.source_context
          end)
          |> Enum.uniq_by(& &1.id)

        case DiwaAgent.Utils.Fuzzy.best_match(target_name, neighbor_contexts) do
          {:ok, matched_ctx} -> {:ok, matched_ctx.id}
          {:error, :no_match} -> {:error, :path_not_found}
        end
    end
  end

  defp list_neighbors(context_id) do
    rels = get_relationships(context_id, :both)

    Enum.map(rels, fn r ->
      {direction, neighbor, type} =
        if r.source_context_id == context_id do
          {:outgoing, r.target_context, r.relationship_type}
        else
          {:incoming, r.source_context, r.relationship_type}
        end

      %{
        id: neighbor.id,
        name: neighbor.name,
        relationship: type,
        direction: direction,
        link_id: r.id
      }
    end)
    |> Enum.sort_by(& &1.name)
  end

  defp get_context_details(context) do
    # Get basic stats
    memory_count =
      Repo.aggregate(
        from(m in DiwaSchema.Core.Memory, where: m.context_id == ^context.id),
        :count,
        :id
      )

    bindings = list_bindings(context.id)

    %{
      id: context.id,
      name: context.name,
      description: context.description,
      memory_count: memory_count,
      bindings: Enum.map(bindings, &"#{&1.binding_type}: #{&1.value}"),
      inserted_at: context.inserted_at,
      updated_at: context.updated_at
    }
  end

  # --- Advanced Traversal ---

  @doc """
  Identifies all contexts that are downstream dependents of the given context.
  If Context A depends on Context B, and we analyze B, A will be in the impact set.
  """
  def analyze_impact(context_id) do
    do_analyze_impact([context_id], MapSet.new())
    # Don't include self
    |> MapSet.delete(context_id)
    |> MapSet.to_list()
    |> Enum.map(fn id -> Repo.get(DiwaSchema.Core.Context, id) end)
  end

  defp do_analyze_impact([], visited), do: visited

  defp do_analyze_impact([id | rest], visited) do
    if MapSet.member?(visited, id) do
      do_analyze_impact(rest, visited)
    else
      new_visited = MapSet.put(visited, id)

      # Find what depends ON this (incoming depends_on)
      upstream_dependents =
        Repo.all(
          from(r in ContextRelationship,
            where: r.target_context_id == ^id and r.relationship_type == "depends_on",
            select: r.source_context_id
          )
        )

      do_analyze_impact(upstream_dependents ++ rest, new_visited)
    end
  end

  @doc """
  Finds the shortest path of relationships between two contexts.
  Returns a list of Context structs if a path exists.
  """
  def find_shortest_path(start_id, end_id) do
    # BFS for shortest path
    queue = :queue.from_list([{start_id, [start_id]}])
    bfs(queue, end_id, MapSet.new())
  end

  defp bfs(queue, target, visited) do
    case :queue.out(queue) do
      {:empty, _} ->
        {:error, :no_path_found}

      {{:value, {current_id, path}}, next_queue} ->
        if current_id == target do
          # Resolve path to context structs
          {:ok, Enum.map(path, fn id -> Repo.get(DiwaSchema.Core.Context, id) end)}
        else
          if MapSet.member?(visited, current_id) do
            bfs(next_queue, target, visited)
          else
            new_visited = MapSet.put(visited, current_id)

            # Get all neighbors (both directions)
            neighbors =
              Repo.all(
                from(r in ContextRelationship,
                  where: r.source_context_id == ^current_id or r.target_context_id == ^current_id,
                  select: {r.source_context_id, r.target_context_id}
                )
              )
              |> Enum.map(fn {src, tgt} -> if src == current_id, do: tgt, else: src end)

            new_queue =
              Enum.reduce(neighbors, next_queue, fn neighbor, q ->
                :queue.in({neighbor, path ++ [neighbor]}, q)
              end)

            bfs(new_queue, target, new_visited)
          end
        end
    end
  end

  # --- Safety Checks ---

  defp circular_dependency?(source_id, target_id) do
    has_path?(target_id, source_id, MapSet.new())
  end

  defp has_path?(current_id, target_id, visited) do
    if current_id == target_id do
      true
    else
      if MapSet.member?(visited, current_id) do
        false
      else
        new_visited = MapSet.put(visited, current_id)

        Repo.all(
          from(r in ContextRelationship,
            where: r.source_context_id == ^current_id and r.relationship_type == "depends_on",
            select: r.target_context_id
          )
        )
        |> Enum.any?(fn next_id -> has_path?(next_id, target_id, new_visited) end)
      end
    end
  end
end

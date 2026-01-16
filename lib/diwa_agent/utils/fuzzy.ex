defmodule DiwaAgent.Utils.Fuzzy do
  @moduledoc """
  Fuzzy string matching utilities for context navigation.
  Uses Jaro-Winkler distance for typo-tolerant matching.
  """

  @doc """
  Returns a score between 0.0 (no match) and 1.0 (exact match).
  """
  def jaro_winkler(s1, s2) do
    s1 = String.downcase(s1)
    s2 = String.downcase(s2)

    if s1 == s2 do
      1.0
    else
      jaro = jaro_distance(s1, s2)

      # Winkler adjustment for common prefix
      prefix_len = common_prefix_length(s1, s2, 0)
      # Weight is usually 0.1, max prefix length 4
      weight = 0.1

      jaro + prefix_len * weight * (1.0 - jaro)
    end
  end

  defp jaro_distance(s1, s2) do
    l1 = String.length(s1)
    l2 = String.length(s2)

    # Matching window
    window = max(0, div(max(l1, l2), 2) - 1)

    {m, t} = matching_and_transpositions(s1, s2, window)

    if m == 0 do
      0.0
    else
      (m / l1 + m / l2 + (m - t / 2) / m) / 3.0
    end
  end

  defp matching_and_transpositions(s1, s2, window) do
    chars1 = String.graphemes(s1)
    chars2 = String.graphemes(s2)

    # For navigation, we often match short queries against long names (e.g. 'diwa' -> 'Project Diwa').
    # Standard Jaro window is too restrictive. We'll use a more lenient window for better sub-word matching.
    len1 = length(chars1)
    len2 = length(chars2)
    effective_window = max(window, abs(len1 - len2) + 2)

    matches1 = for _ <- chars1, do: {nil, false}
    matches2 = for _ <- chars2, do: {nil, false}

    # First pass: find matches within window
    {matches1, matches2, m_count} =
      find_matches(chars1, chars2, effective_window, matches1, matches2)

    if m_count == 0 do
      {0, 0}
    else
      # Second pass: count transpositions
      t_count = count_transpositions(matches1, matches2)
      {m_count, t_count}
    end
  end

  defp find_matches(chars1, chars2, window, m1, m2) do
    l2 = length(chars2)

    Enum.reduce(Enum.with_index(chars1), {m1, m2, 0}, fn {c1, i}, {acc_m1, acc_m2, count} ->
      start_j = max(0, i - window)
      end_j = min(l2 - 1, i + window)

      # Find first unused char in chars2 that matches c1 within window
      found_j =
        Enum.find(start_j..end_j, fn j ->
          {_, matched} = Enum.at(acc_m2, j)
          !matched && Enum.at(chars2, j) == c1
        end)

      if found_j do
        new_m1 = List.replace_at(acc_m1, i, {c1, true})
        new_m2 = List.replace_at(acc_m2, found_j, {Enum.at(chars2, found_j), true})
        {new_m1, new_m2, count + 1}
      else
        {acc_m1, acc_m2, count}
      end
    end)
  end

  defp count_transpositions(matches1, matches2) do
    # Extract matched characters in order
    m1_chars = Enum.filter(matches1, &elem(&1, 1)) |> Enum.map(&elem(&1, 0))
    m2_chars = Enum.filter(matches2, &elem(&1, 1)) |> Enum.map(&elem(&1, 0))

    # Transpositions are mismatched orders
    Enum.zip(m1_chars, m2_chars)
    |> Enum.count(fn {c1, c2} -> c1 != c2 end)
    |> div(2)
  end

  defp common_prefix_length(s1, s2, count) when count < 4 do
    case {s1, s2} do
      {<<c1::utf8, rest1::binary>>, <<c2::utf8, rest2::binary>>} when c1 == c2 ->
        common_prefix_length(rest1, rest2, count + 1)

      _ ->
        count
    end
  end

  defp common_prefix_length(_, _, count), do: count

  @doc """
  Finds the best match for `query` in a list of `candidates`.
  Each candidate should be a map or struct with a field (default :name).
  Returns `{:ok, best_match}` or `{:error, :no_match}`.
  Threshold defaults to 0.6.
  """
  def best_match(query, candidates, field \\ :name, threshold \\ 0.6) do
    query_down = String.downcase(query)

    results =
      candidates
      |> Enum.map(fn cand ->
        cand_name = Map.get(cand, field)
        cand_name_down = String.downcase(cand_name)

        # Hybrid scoring
        score =
          cond do
            query_down == cand_name_down ->
              1.0

            String.contains?(cand_name_down, query_down) ->
              # Substring match gets a high base score, scaled by relative length
              0.85 + String.length(query) / String.length(cand_name) * 0.1

            true ->
              jaro_winkler(query, cand_name)
          end

        {cand, score}
      end)
      |> Enum.filter(fn {_, score} -> score >= threshold end)
      |> Enum.sort_by(fn {_, score} -> score end, :desc)

    case results do
      [{best, _} | _] -> {:ok, best}
      [] -> {:error, :no_match}
    end
  end
end

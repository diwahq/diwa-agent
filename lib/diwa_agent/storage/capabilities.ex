defmodule DiwaAgent.Storage.Capabilities do
  @moduledoc """
  Detects available storage capabilities for graceful feature degradation.

  Community Edition: Always uses binary embeddings with ILIKE text search
  Enterprise Edition: Can use pgvector if extension is available
  """

  require Logger

  @doc """
  Check if pgvector extension is available and functional.
  Returns {:ok, true} if available, {:ok, false} otherwise.
  """
  def pgvector_available? do
    vector_type = Application.get_env(:diwa_agent, :vector_type, :binary)

    case vector_type do
      :binary ->
        {:ok, false}

      :vector ->
        # Try to query for the extension
        check_pgvector_extension()

      _ ->
        {:ok, false}
    end
  end

  defp check_pgvector_extension do
    try do
      result =
        DiwaAgent.Repo.query(
          "SELECT 1 FROM pg_extension WHERE extname = 'vector'",
          []
        )

      case result do
        {:ok, %{num_rows: 1}} ->
          {:ok, true}

        {:ok, %{num_rows: 0}} ->
          Logger.info("[Capabilities] pgvector extension not installed - using ILIKE text search")
          {:ok, false}

        _ ->
          {:ok, false}
      end
    rescue
      _ ->
        Logger.debug(
          "[Capabilities] Cannot query pg_extension (likely SQLite) - using ILIKE search"
        )

        {:ok, false}
    end
  end

  @doc """
  Get search capability mode: :vector, :fulltext, or :ilike
  """
  def search_mode do
    case pgvector_available?() do
      {:ok, true} ->
        :vector

      {:ok, false} ->
        adapter = Application.get_env(:diwa_agent, DiwaAgent.Repo)[:adapter]

        if adapter == Ecto.Adapters.Postgres do
          :fulltext
        else
          :ilike
        end
    end
  end

  @doc """
  Get human-readable capability summary for status messages.
  """
  def summary do
    mode = search_mode()
    vector_type = Application.get_env(:diwa_agent, :vector_type, :binary)

    %{
      search_mode: mode,
      vector_type: vector_type,
      description: describe_mode(mode)
    }
  end

  defp describe_mode(:vector), do: "Vector similarity search (pgvector)"
  defp describe_mode(:fulltext), do: "Full-text search (PostgreSQL)"
  defp describe_mode(:ilike), do: "Basic text search (ILIKE)"
end

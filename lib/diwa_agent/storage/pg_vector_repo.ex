defmodule DiwaAgent.Storage.PgVectorRepo do
  @moduledoc """
  PostgreSQL implementation of VectorRepo using Ecto and pgvector.
  """
  @behaviour DiwaAgent.Storage.VectorRepoBehaviour
  
  import Ecto.Query
  alias DiwaAgent.Repo
  alias DiwaAgent.Storage.Schemas.Memory
  
  @impl true
  def upsert_embedding(id, vector, _metadata) do
    # Check configured type
    type = Application.get_env(:diwa_agent, :vector_type, :binary)
    
    value = 
      case type do
        :binary -> :erlang.term_to_binary(vector)
        _ -> vector
      end
      
    query = from(m in Memory, where: m.id == ^id)
    
    try do
      # use update_all to avoid fetching struct first
      {count, _} = Repo.update_all(query, set: [embedding: value])
      
      if count == 0 do 
        {:error, :not_found}
      else
        :ok
      end
    rescue
      e -> {:error, e}
    end
  end
  
  @impl true
  def search(query_vector, limit, opts) do
    type = Application.get_env(:diwa_agent, :vector_type, :binary)
    
    if type == :binary do
       # Vector search is not available in Community/Binary mode
       {:error, :vector_search_disabled}
    else
       # Enterprise/Local-Enterprise mode with pgvector
       perform_vector_search(query_vector, limit, opts)
    end
  end
  
  defp perform_vector_search(query_vector, limit, opts) do
    context_id = Keyword.get(opts, :context_id)
    
    # Using fragment for cosine distance (operator <=>)
    # We order by distance ASC (closest first)
    # Cosine distance: 1 - cosine_similarity. So 0 is identical.
    
    query = 
      from(m in Memory,
        select: %{id: m.id, similarity: 1 - fragment("? <=> ?::vector", m.embedding, ^query_vector)},
        order_by: fragment("? <=> ?::vector", m.embedding, ^query_vector),
        limit: ^limit
      )
      
    query = 
      if context_id do
        from(m in query, where: m.context_id == ^context_id)
      else
        query 
      end
      
    {:ok, Repo.all(query)}
  end
  
  @impl true
  def delete_embedding(id) do
    query = from(m in Memory, where: m.id == ^id)
    Repo.update_all(query, set: [embedding: nil])
    :ok
  end
end

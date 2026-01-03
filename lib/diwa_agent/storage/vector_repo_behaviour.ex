defmodule DiwaAgent.Storage.VectorRepoBehaviour do
  @moduledoc """
  Behaviour for storing and retrieving vectors.
  Allows abstracting PostgreSQL/pgvector for testing.
  """
  
  @type id :: String.t()
  @type vector :: [float()]
  @type metadata :: map()
  
  @callback upsert_embedding(id(), vector(), metadata()) :: :ok | {:error, term()}
  @callback search(vector(), integer(), keyword()) :: {:ok, [map()]} | {:error, term()}
  @callback delete_embedding(id()) :: :ok | {:error, term()}
end

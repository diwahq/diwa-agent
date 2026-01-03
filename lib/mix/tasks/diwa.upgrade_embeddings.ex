defmodule Mix.Tasks.DiwaAgent.UpgradeEmbeddings do
  use Mix.Task
  require Logger

  @shortdoc "Regenerates vector embeddings for all memories."
  @moduledoc """
  Regenerates vector embeddings for all memories in the database.

  This is useful when:
  1. Upgrading from Community (binary) to Enterprise (pgvector) edition.
  2. Changing the embedding model (e.g. from MiniLM to OpenAI).
  3. Backfilling embeddings for old data.

  ## Storage Strategy
  - If running in Community mode (:binary), it stores Erlang binary blobs.
  - If running in Enterprise mode (:vector), it stores native pgvector embeddings.

  ## Usage
      mix diwa.upgrade_embeddings
      mix diwa.upgrade_embeddings --force (Overwrites existing embeddings)
  """

  def run(args) do
    Mix.Task.run("app.start")
    
    force = "--force" in args
    
    Logger.info("Starting embedding upgrade/backfill...")
    Logger.info("Edition: #{DiwaAgent.Edition.current()}")
    Logger.info("Vector Type: #{Application.get_env(:diwa_agent, :vector_type, :unknown)}")
    
    # Ensure Repos are started
    DiwaAgent.Repo.start_link()
    
    import Ecto.Query
    alias DiwaAgent.Repo
    alias DiwaAgent.Storage.Schemas.Memory
    
    # Query memories
    query = from(m in Memory)
    
    query = 
      if force do
        query
      else
        from(m in query, where: is_nil(m.embedding))
      end
      
    memories = Repo.all(query)
    total = length(memories)
    
    Logger.info("Found #{total} memories to process.")
    
    embedding_module = Application.get_env(:diwa_agent, :embedding_module, DiwaAgent.AI.Embeddings)
    vector_repo = Application.get_env(:diwa_agent, :vector_repo_module, DiwaAgent.Storage.PgVectorRepo)
    
    Enum.each(Enum.with_index(memories), fn {memory, idx} ->
      if rem(idx, 10) == 0, do: Logger.info("Processing #{idx}/#{total}...")
      
      case embedding_module.generate_embedding(memory.content) do
        {:ok, vector} ->
           # Upsert using the repo (handles binary/vector logic)
           case vector_repo.upsert_embedding(memory.id, vector, %{}) do
             :ok -> :ok
             {:error, e} -> Logger.error("Failed to save embedding for #{memory.id}: #{inspect(e)}")
           end
        {:error, e} ->
           Logger.error("Failed to generate embedding for #{memory.id}: #{inspect(e)}")
      end
    end)
    
    Logger.info("Upgrade complete.")
  end
end

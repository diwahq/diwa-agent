defmodule DiwaAgent.Test.Mocks do
  # This file handles mock definitions to ensure they are available during compilation/test loading
end

Mox.defmock(DiwaAgent.Consensus.ClusterMock, for: DiwaAgent.Consensus.ClusterBehaviour)

defmodule DiwaAgent.Test.FakeEmbeddings do
  def generate_embedding(text) do
    # Deterministic hash-based "embedding" for testing
    hash = :erlang.phash2(text)
    # Return a 4-float vector
    {:ok, [hash * 1.0, hash * 0.5, hash * 0.25, hash * 0.125]}
  end
end

defmodule DiwaAgent.Test.FakeVectorRepo do
  @table :diwa_agent_fake_vector_repo

  def start_link(_opts \\ []) do
    case :ets.info(@table) do
      :undefined -> :ets.new(@table, [:named_table, :set, :public])
      _ -> :ok
    end
    {:ok, self()}
  end

  def upsert_embedding(id, vector, _metadata \\ %{}) do
    :ets.insert(@table, {id, vector})
    :ok
  end

  def search(query_vector, limit, _opts \\ []) do
    # Very simple Euclidean distance search
    all = :ets.tab2list(@table)
    
    results = 
      all
      |> Enum.map(fn {id, vec} ->
        dist = calculate_distance(query_vector, vec)
        # Similarity = 1 / (1 + distance)
        %{id: id, similarity: 1.0 / (1.0 + dist)}
      end)
      |> Enum.sort_by(& &1.similarity, :desc)
      |> Enum.take(limit)

    {:ok, results}
  end

  defp calculate_distance(v1, v2) do
    Enum.zip(v1, v2)
    |> Enum.map(fn {a, b} -> (a - b) * (a - b) end)
    |> Enum.sum()
    |> :math.sqrt()
  end
end

defmodule DiwaAgent.Consensus.ByzantineDetector do
  use GenServer

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    {:ok, %{}}
  end

  def reset_state do
    GenServer.call(__MODULE__, :reset)
  end

  def handle_call(:reset, _from, _state) do
    {:reply, :ok, %{}}
  end
end

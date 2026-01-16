defmodule DiwaAgent.AI.Embeddings do
  @moduledoc """
  Stub for AI Embeddings.
  Real embeddings generation requires an LLM provider integration.
  """

  def generate_embedding(_text) do
    if Application.get_env(:diwa_agent, :mock_embeddings) do
      {:ok, Enum.map(1..1536, fn _ -> 0.1 end)}
    else
      # Return nil or error in community edition
      {:error, :not_implemented}
    end
  end
end

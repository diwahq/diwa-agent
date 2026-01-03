defmodule DiwaAgent.AI.Embeddings do
  @moduledoc """
  Stub for AI Embeddings.
  Real embeddings generation requires an LLM provider integration.
  """

  def generate_embedding(_text) do
    # Return nil or error in community edition
    {:error, :not_implemented}
  end
end

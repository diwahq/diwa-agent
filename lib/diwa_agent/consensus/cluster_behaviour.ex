defmodule DiwaAgent.Consensus.ClusterBehaviour do
  @moduledoc """
  Behaviour for Cluster Management.
  """

  @callback get_cluster_status(list()) :: {:ok, map()} | {:error, any()}
  @callback get_byzantine_nodes(list()) :: {:ok, list()} | {:error, any()}
  @callback arbitrate_conflict(String.t(), String.t()) :: {:ok, any()} | {:error, any()}
end

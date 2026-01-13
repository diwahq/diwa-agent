defmodule DiwaAgent.Cloud.Adapter do
  @moduledoc """
  Behaviour for Diwa Cloud Adapters.
  Defines the contract for synchronizing local state with the Diwa Cloud (or compatible self-hosted instances).
  """

  @callback sync_context(context_id :: String.t(), data :: map()) :: {:ok, map()} | {:error, any()}
  @callback sync_memory(memory_id :: String.t(), data :: map()) :: {:ok, map()} | {:error, any()}
  @callback health_check() :: :ok | {:error, any()}
  
  # Optional: For future bidirectional sync
  # @callback fetch_pending_updates(context_id :: String.t()) :: {:ok, list()} | {:error, any()}
end

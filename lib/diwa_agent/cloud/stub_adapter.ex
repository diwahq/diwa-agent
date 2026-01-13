defmodule DiwaAgent.Cloud.StubAdapter do
  @moduledoc """
  Stub implementation of the Diwa Cloud Adapter for development/offline use.
  """
  @behaviour DiwaAgent.Cloud.Adapter
  
  require Logger

  @impl true
  def health_check do
    Logger.debug("Cloud Stub: Health check passed (simulated)")
    :ok
  end

  @impl true
  def sync_context(context_id, _data) do
    Logger.debug("Cloud Stub: Synced context #{context_id} (simulated)")
    {:ok, %{"sync_status" => "simulated", "id" => context_id}}
  end

  @impl true
  def sync_memory(memory_id, _data) do
    Logger.debug("Cloud Stub: Synced memory #{memory_id} (simulated)")
    {:ok, %{"sync_status" => "simulated", "id" => memory_id}}
  end
end

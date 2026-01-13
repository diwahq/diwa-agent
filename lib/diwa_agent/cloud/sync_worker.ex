defmodule DiwaAgent.Cloud.SyncWorker do
  @moduledoc """
  Background worker that processes the SyncQueue and calls the Cloud Client.
  """
  use GenServer
  require Logger
  alias DiwaAgent.Cloud.{SyncQueue, Client}

  @poll_interval 5_000 # 5 seconds

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    if System.get_env("DIWA_ENABLE_CLOUD_SYNC") == "true" do
      schedule_poll()
      {:ok, %{status: :active}}
    else
      {:ok, %{status: :inactive}}
    end
  end

  def handle_info(:poll, state) do
    process_batch()
    schedule_poll()
    {:noreply, state}
  end

  defp process_batch do
    batches = SyncQueue.next_batch(10)
    Enum.each(batches, &process_item/1)
  end

  defp process_item(item) do
    case item.type do
      "context" ->
        # For simplicity, we assume the payload contains the necessary fields for a context-like map
        case Client.sync_context(item.payload) do
          :ok -> SyncQueue.mark_completed(item.id)
          {:error, reason} -> SyncQueue.mark_failed(item.id, reason)
        end
      "memory" ->
        # Map payload back to something Client.sync_memory(memory) can use
        # In a real app, we might store the full struct or use a specialized mapper
        case Client.sync_memory(item.payload) do
          :ok -> SyncQueue.mark_completed(item.id)
          {:error, reason} -> SyncQueue.mark_failed(item.id, reason)
        end
    end
  end

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval)
  end
end

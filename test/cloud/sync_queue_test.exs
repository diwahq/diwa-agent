defmodule DiwaAgent.Cloud.SyncQueueIntegrationTest do
  use ExUnit.Case
  import Mox
  alias DiwaAgent.Cloud.{SyncQueue, SyncWorker}
  alias DiwaAgent.Repo

  setup :verify_on_exit!
  
  setup do
    DiwaAgent.TestHelper.setup_test_db()
    
    # Override the client implementation to use the mock
    Application.put_env(:diwa_agent, :cloud_client, DiwaAgent.Cloud.ClientMock)
    
    on_exit(fn ->
      Application.delete_env(:diwa_agent, :cloud_client)
      DiwaAgent.TestHelper.cleanup_test_db(nil)
    end)
    
    :ok
  end

  test "retry logic: handles offline failure then recovers" do
    # 1. Enqueue item
    context_payload = %{
      id: "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11", 
      name: "Test Context", 
      organization_id: "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22"
    }
    {:ok, item} = SyncQueue.enqueue("context", context_payload)
    
    # 2. Simulate Offline (failure)
    # We expect one call that fails
    expect(DiwaAgent.Cloud.ClientMock, :sync_context, fn _ -> 
      {:error, :econnrefused}
    end)
    
    # Trigger processing manually by spinning up a worker
    # We name it uniquely to avoid collision with any running app worker
    {:ok, pid} = GenServer.start_link(SyncWorker, [], name: :test_worker_1)
    Ecto.Adapters.SQL.Sandbox.allow(DiwaAgent.Repo, self(), pid)
    Mox.allow(DiwaAgent.Cloud.ClientMock, self(), pid)
    
    # Send poll
    send(pid, :poll)
    
    # Allow async processing
    Process.sleep(100)
    
    # Check status -> Should be FAILED
    updated_item = Repo.get!(SyncQueue, item.id)
    assert updated_item.status == "failed"
    assert updated_item.attempts == 1
    assert updated_item.last_error =~ ":econnrefused"
    
    # 3. Simulate Online (Recovery)
    # We expect another call that succeeds
    expect(DiwaAgent.Cloud.ClientMock, :sync_context, fn _ -> :ok end)
    
    # Send poll again (retry)
    send(pid, :poll)
    
    Process.sleep(100)
     
    # Check status -> Should be COMPLETED
    completed_item = Repo.get!(SyncQueue, item.id)
    assert completed_item.status == "completed"
    
    GenServer.stop(pid)
  end
end

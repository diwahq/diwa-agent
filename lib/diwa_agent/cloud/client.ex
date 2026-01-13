defmodule DiwaAgent.Cloud.Client do
  @moduledoc """
  Client for synchronization with Diwa Cloud (Enterprise).
  """

  @callback sync_context(map()) :: :ok | {:error, term()}
  @callback sync_memory(map()) :: :ok | {:error, term()}

  @doc """
  Sync a context with Diwa Cloud.
  """
  def sync_context(context) do
    impl().sync_context(context)
  end
  
  def sync_memory(memory) do
    impl().sync_memory(memory)
  end

  defp impl do
    Application.get_env(:diwa_agent, :cloud_client, DiwaAgent.Cloud.Client.Http)
  end
end

defmodule DiwaAgent.Cloud.Client.Http do
  @behaviour DiwaAgent.Cloud.Client
  
  require Logger
  
  @default_base_url "http://localhost:4000/api/v1"

  def sync_context(context) do
    url = "#{base_url()}/sync/context"
    body = %{
      id: context.id,
      name: context.name,
      description: context.description,
      organization_id: context.organization_id
    }

    case post(url, body) do
      {:ok, %{status: 201}} -> :ok
      {:ok, %{status: status, body: body}} ->
        Logger.warning("[CloudClient] Context sync failed (#{status}): #{inspect(body)}")
        {:error, :sync_failed}
      {:error, reason} ->
        Logger.error("[CloudClient] Context sync error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Sync a memory with Diwa Cloud.
  """
  def sync_memory(memory) do
    url = "#{base_url()}/sync/memory"
    body = %{
      context_id: memory.context_id,
      content: memory.content,
      options: %{
        metadata: memory.metadata,
        actor: memory.actor,
        project: memory.project,
        tags: memory.tags,
        parent_id: memory.parent_id,
        external_ref: memory.external_ref,
        severity: memory.severity
      }
    }

    case post(url, body) do
      {:ok, %{status: 201}} -> :ok
      {:ok, %{status: status, body: body}} ->
        Logger.warning("[CloudClient] Memory sync failed (#{status}): #{inspect(body)}")
        {:error, :sync_failed}
      {:error, reason} ->
        Logger.error("[CloudClient] Memory sync error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp post(url, body) do
    Req.post(url, json: body, headers: auth_headers())
  end

  defp auth_headers do
    token = System.get_env("DIWA_CLOUD_TOKEN")
    if token do
      [{"authorization", "Bearer #{token}"}]
    else
      []
    end
  end

  defp base_url do
    System.get_env("DIWA_CLOUD_URL") || @default_base_url
  end
end

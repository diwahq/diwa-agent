defmodule DiwaAgent.Cloud.HttpAdapter do
  @moduledoc """
  HTTP implementation of the Diwa Cloud Adapter using Req.
  Communicates with the Diwa Cloud API.
  """
  @behaviour DiwaAgent.Cloud.Adapter
  
  require Logger

  @impl true
  def health_check do
    url = config_url("/health")
    
    case Req.get(url, headers: headers()) do
      {:ok, %{status: 200}} -> :ok
      {:ok, %{status: status}} -> {:error, "Health check failed with status: #{status}"}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def sync_context(context_id, data) do
    url = config_url("/v1/contexts/#{context_id}/sync")
    
    case Req.post(url, json: data, headers: headers()) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: 201, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, "Sync failed: #{status} - #{inspect(body)}"}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def sync_memory(memory_id, data) do
    url = config_url("/v1/memories/#{memory_id}/sync")
    
    case Req.post(url, json: data, headers: headers()) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: 201, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, "Memory sync failed: #{status} - #{inspect(body)}"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp config_url(path) do
    base = Application.get_env(:diwa_agent, :cloud_api_url, "https://api.diwa.one")
    URI.merge(base, path) |> to_string()
  end

  defp headers do
    token = Application.get_env(:diwa_agent, :cloud_api_token)
    [
      {"Authorization", "Bearer #{token}"},
      {"User-Agent", "DiwaAgent/1.0.0"}
    ]
  end
end

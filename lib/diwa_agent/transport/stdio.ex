defmodule DiwaAgent.Transport.Stdio do
  @moduledoc """
  STDIO transport layer for JSON-RPC 2.0 communication.

  Reads line-delimited JSON from stdin and writes responses to stdout.
  """

  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.debug("[DiwaAgent.Transport.Stdio] Init called")

    # Start reading from stdin
    Task.start_link(fn -> read_loop() end)

    {:ok, %{}}
  end

  defp read_loop do
    case IO.read(:stdio, :line) do
      :eof ->
        Logger.info("[DiwaAgent.Transport.Stdio] EOF received, shutting down")
        System.halt(0)

      {:error, reason} ->
        Logger.error("[DiwaAgent.Transport.Stdio] Read error: #{inspect(reason)}")
        System.halt(1)

      line when is_binary(line) ->
        line = String.trim(line)

        unless line == "" do
          handle_input(line)
        end

        read_loop()
    end
  end

  defp handle_input(line) do
    try do
      case DiwaAgent.Server.handle_message(line) do
        {:ok, response} ->
          send_response(response)
  
        {:error, reason} ->
          Logger.error("[DiwaAgent.Transport.Stdio] Error handling message: #{inspect(reason)}")
      end
    rescue
      e ->
        Logger.error("[DiwaAgent.Transport.Stdio] Crash during message handling: #{inspect(e)}")
        # Construct an error response if we have the ID, but we don't easily have it here since parsing happens in Server.
        # So we just log to stderr and hope for the best.
    end
  end

  defp send_response(nil), do: :ok

  defp send_response(response) do
    # Log the response ID for debugging
    response_id = Map.get(response, "id")
    
    # Use unicode_safe to ensure all characters are properly escaped
    # This prevents "Bad escaped character" errors in strict JSON parsers
    json = Jason.encode!(response, escape: :unicode_safe)
    
    # Log successful encoding for debugging
    Logger.debug("[DiwaAgent.Transport.Stdio] Sending response for ID: #{inspect(response_id)}, size: #{byte_size(json)} bytes")
    
    # Use binwrite to avoid any encoding/device ambiguity
    IO.binwrite(:stdio, json <> "\n")
  rescue
    e ->
      response_id = Map.get(response, "id")
      Logger.error("[DiwaAgent.Transport.Stdio] JSON encoding failed for response ID: #{inspect(response_id)}")
      Logger.error("[DiwaAgent.Transport.Stdio] Error: #{inspect(e)}")
      Logger.error("[DiwaAgent.Transport.Stdio] Response was: #{inspect(response, limit: 500, printable_limit: 200)}")
      
      # Send a minimal error response
      fallback = ~s({"jsonrpc":"2.0","id":#{inspect(response_id)},"error":{"code":-32603,"message":"Internal error: JSON encoding failed"}})
      IO.binwrite(:stdio, fallback <> "\n")
  end
end

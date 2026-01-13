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

  def init(_opts) do
    # Configure stdout for reliable UTF-8 transmission
    :io.setopts(:standard_io, [binary: true, encoding: :utf8])
    
    # Start reading from stdin
    Task.start_link(fn -> read_loop() end)

    {:ok, %{}}
  end

  defp read_loop do
    case IO.read(:stdio, :line) do
      :eof ->
        File.write!("/Users/ei/codes/diwa/diwa-agent/mcp_traffic.log", "[IN] EOF\n", [:append])
        Logger.info("[DiwaAgent.Transport.Stdio] EOF received, shutting down")
        System.halt(0)

      {:error, reason} ->
        File.write!("/Users/ei/codes/diwa/diwa-agent/mcp_traffic.log", "[IN] ERROR: #{inspect(reason)}\n", [:append])
        Logger.error("[DiwaAgent.Transport.Stdio] Read error: #{inspect(reason)}")
        System.halt(1)

      line when is_binary(line) ->
        File.write!("/Users/ei/codes/diwa/diwa-agent/mcp_traffic.log", "[IN] #{line}", [:append])
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
          File.write!("/Users/ei/codes/diwa/diwa-agent/mcp_traffic.log", "[ERR] #{inspect(reason)}\n", [:append])
          Logger.error("[DiwaAgent.Transport.Stdio] Error handling message: #{inspect(reason)}")
      end
    rescue
      e ->
        msg = "[DiwaAgent.Transport.Stdio] Crash during message handling: #{inspect(e)}"
        File.write!("/Users/ei/codes/diwa/diwa-agent/mcp_traffic.log", "[CRASH] #{inspect(e)}\n", [:append])
        IO.puts(:stderr, msg)
        Logger.error(msg)
    end
  end

  defp send_response(nil), do: :ok

  defp send_response(response) do
    # Use unicode_safe to ensure all characters are properly escaped
    json = Jason.encode!(response, escape: :unicode_safe)
    
    # Write to log
    File.write!("/Users/ei/codes/diwa/diwa-agent/mcp_traffic.log", "[OUT] #{json}\n", [:append])

    # Write to standard output
    IO.puts(:standard_io, json)
  rescue
    _ ->
      response_id = Map.get(response, "id")
      msg = "[DiwaAgent.Transport.Stdio] JSON encoding failed for response ID: #{inspect(response_id)}"
      IO.puts(:stderr, msg)
      Logger.error(msg)
      
      # Send a minimal error response directly to stdout
      fallback = ~s({"jsonrpc":"2.0","id":#{inspect(response_id)},"error":{"code":-32603,"message":"Internal error: JSON encoding failed"}})
      IO.puts(:standard_io, fallback)
  end
end

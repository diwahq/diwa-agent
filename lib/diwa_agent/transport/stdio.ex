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
    :io.setopts(:standard_io, binary: true, encoding: :utf8)

    # Start reading from stdin
    Task.start_link(fn -> read_loop() end)

    {:ok, %{}}
  end

  defp read_loop do
    # Use binread to avoid potential encoding issues during the read itself
    case IO.binread(:stdio, :line) do
      :eof ->
        Logger.info("[DiwaAgent.Transport.Stdio] EOF received, shutting down")
        System.halt(0)

      {:error, reason} ->
        Logger.error("[DiwaAgent.Transport.Stdio] Read error: #{inspect(reason)}")
        Process.sleep(100)
        read_loop()

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
        msg = "[DiwaAgent.Transport.Stdio] Crash during message handling: #{inspect(e)}"
        IO.puts(:stderr, msg)
        Logger.error(msg)
    end
  end

  defp send_response(nil), do: :ok

  defp send_response(response) do
    json = Jason.encode!(response, escape: :unicode_safe)

    # Use IO.binwrite to standard_io which is configured for binary/utf8
    # This proved more reliable than raw :file.write(1) in the current environment
    IO.binwrite(:standard_io, json <> "\n")
  rescue
    e ->
      response_id = Map.get(response, "id")

      msg =
        "[DiwaAgent.Transport.Stdio] JSON encoding failed for response ID: #{inspect(response_id)}. Error: #{inspect(e)}"

      IO.puts(:stderr, msg)
      Logger.error(msg)

      fallback =
        ~s({"jsonrpc":"2.0","id":#{inspect(response_id)},"error":{"code":-32603,"message":"Internal error: JSON encoding failed"}})

      IO.binwrite(:standard_io, fallback <> "\n")
  end
end

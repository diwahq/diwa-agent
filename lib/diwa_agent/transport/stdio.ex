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
    IO.puts(:stderr, "[DiwaAgent.Transport.Stdio] DEBUG: Init called")
    Logger.info("[DiwaAgent.Transport.Stdio] Starting stdio transport")

    # Start reading from stdin
    Task.start_link(fn -> read_loop() end)

    {:ok, %{}}
  end

  defp read_loop do
    IO.puts(:stderr, "[DiwaAgent.Transport.Stdio] DEBUG: Calling IO.read")
    case IO.read(:stdio, :line) do
      :eof ->
        Logger.info("[DiwaAgent.Transport.Stdio] EOF received, shutting down")
        System.halt(0)

      {:error, reason} ->
        Logger.error("[DiwaAgent.Transport.Stdio] Read error: #{inspect(reason)}")
        System.halt(1)

      line when is_binary(line) ->
        Logger.info("[DiwaAgent.Transport.Stdio] Received line: #{String.slice(line, 0, 50)}...")
        line = String.trim(line)

        unless line == "" do
          handle_input(line)
        end

        read_loop()
    end
  end

  defp handle_input(line) do
    case DiwaAgent.Server.handle_message(line) do
      {:ok, response} ->
        send_response(response)

      {:error, reason} ->
        Logger.error("[DiwaAgent.Transport.Stdio] Error handling message: #{inspect(reason)}")
    end
  end

  defp send_response(nil), do: :ok

  defp send_response(response) do
    json = Jason.encode!(response)
    IO.puts(json)
  end
end

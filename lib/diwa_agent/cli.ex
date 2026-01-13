defmodule DiwaAgent.CLI do
  @moduledoc """
  Command-line interface for the Diwa MCP server.
  """

  def main(args) do
    case args do
      ["version"] ->
        IO.puts(:stderr, "Diwa MCP Context Server v0.1.0")

      ["help"] ->
        print_help()

      [] ->
        start_server()

      ["start"] ->
        start_server()

      _ ->
        IO.puts(:stderr, "Unknown command. Use 'diwa help' for usage information.")
        System.halt(1)
    end
  end

  defp start_server do
    # Configure Logger to use stderr BEFORE starting the application
    # This ensures migration errors and other startup logs don't pollute stdout
    Logger.configure(level: :warning)
    :logger.add_handler(:default, :logger_std_h, %{
      config: %{type: :standard_error},
      formatter: Logger.Formatter.new()
    })
    Application.put_env(:logger, :console, device: :standard_error)
    
    # Perfectly silent startup
    case Application.ensure_all_started(:diwa_agent) do
      {:ok, _} ->
        # Just stay alive
        Process.sleep(:infinity)

      {:error, reason} ->
        IO.puts(:stderr, "[Diwa] Failed to start server: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp print_help do
    IO.puts(:stderr, """
    Diwa MCP Context Server v0.1.0

    Usage: diwa [COMMAND]
    COMMANDS:
        start       Start the MCP server
        version     Display version
        help        Show this help
    """)
  end
end

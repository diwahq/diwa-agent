# launch_mcp.exs
# This script starts the Diwa application with all output redirected to stderr
# except for the JSON-RPC responses.

# 1. Completely silence the logger during startup to prevent any stdout pollution
Logger.configure(level: :none)
Logger.configure_backend(:console, device: :standard_error)

# 2. Silence Erlang error_logger reports
:logger.set_primary_config(:level, :none)

# 3. Start the application
case Application.ensure_all_started(:diwa_agent) do
  {:ok, _} ->
    # Re-enable logger at warning level after startup
    Logger.configure(level: :warning)
    IO.puts(:stderr, "[Diwa] Application started successfully.")
    # The application itself starts the DiwaAgent.Server
    # We just need to keep the process alive
    Process.sleep(:infinity)

  {:error, reason} ->
    IO.puts(:stderr, "[Diwa] Failed to start application: #{inspect(reason)}")
    System.halt(1)
end

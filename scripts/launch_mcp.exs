# launch_mcp.exs
# This script starts the Diwa application with all output redirected to stderr
# except for the JSON-RPC responses.

# CRITICAL: Suppress ALL output to stdout before starting
# This prevents breaking the MCP JSON-RPC handshake



# 1. Force logger to stderr BEFORE any applications start
# Note: creating/removing handlers requires Logger/Erlang logger to be running.
# Since we use --no-start, we might need to rely on the fact that the VM starts logger kernel?
# But to be safe, we remove the default handler which prints to stdout.
:logger.remove_handler(:default)

# Remove the console backend (which Mix might have attached to stdout)
# and re-add it with explicit configuration to stderr.
Logger.remove_backend(:console)
Application.put_env(:logger, :console, device: :standard_error)
Logger.add_backend(:console)
Logger.configure_backend(:console, device: :standard_error)

Logger.configure(level: :warning)

# 2. Force all logger output to stderr  
Application.put_env(:logger, :console, device: :standard_error)

# 3. Start the application
case Application.ensure_all_started(:diwa_agent) do
  {:ok, _} ->
    IO.puts(:stderr, "[DiwaAgent] Application started successfully.")
    # The application itself starts the Diwa.Server
    # We just need to keep the process alive
    Process.sleep(:infinity)

  {:error, reason} ->
    IO.puts(:stderr, "[DiwaAgent] Failed to start application: #{inspect(reason)}")
    System.halt(1)
end

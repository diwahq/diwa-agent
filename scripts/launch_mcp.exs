# launch_mcp.exs
# This script starts the Diwa application with all output redirected to stderr
# except for the JSON-RPC responses.

# 1. Force all logger output to stderr
Application.put_env(:logger, :console, device: :standard_error)

# 2. Start the application
case Application.ensure_all_started(:diwa_agent) do
  {:ok, _} ->
    IO.puts(:stderr, "[Diwa] Application started successfully.")
    # Verify stdout is working
    IO.puts("JSON-RPC-READY")
    # The application itself starts the Diwa.Server
    # We just need to keep the process alive
    Process.sleep(:infinity)

  {:error, reason} ->
    IO.puts(:stderr, "[Diwa] Failed to start application: #{inspect(reason)}")
    System.halt(1)
end

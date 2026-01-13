# launch_mcp.exs
# This script configures logging and keeps the MCP server running
require Logger

# 1. Force Logger to stderr and set level
Logger.configure(level: :warning)
Application.put_env(:logger, :console, [device: :standard_error])

# 2. Print status to stderr
IO.puts(:stderr, "[launch_mcp.exs] MCP server is running...")

# Keep the process alive
Process.sleep(:infinity)

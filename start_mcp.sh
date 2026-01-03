#!/bin/bash
export MIX_ENV=dev

# 1. Compile everything silently (stderr) to avoid "Compiling..." messages on stdout
#    which break the JSON-RPC handshake.
{
  mix deps.get
  mix compile
} >&2

# 2. Run the MCP launch script
#    --no-halt is implied by the script sleeping forever, but we use mix run.
#    --no-compile prevents Mix from checking again and printing things.
export DIWA_DISABLE_WEB=true
exec mix run --no-compile --no-start scripts/launch_mcp.exs

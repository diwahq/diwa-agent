#!/bin/bash
set -e
export MIX_ENV=dev
cd "$(dirname "$0")"

# 1. Ensure dependencies and compilation are done (redirect ALL to stderr)
mix deps.get >&2 2>&1
mix compile >&2 2>&1

# 2. Run MCP server with stdout reserved for JSON-RPC only
#    Key insight: The Stdio transport uses :file.write(1, json) which writes directly
#    to file descriptor 1 (stdout), bypassing Elixir's IO system.
#    Meanwhile, ALL other output (Mix, Logger, warnings) goes to stderr.
export DIWA_DISABLE_WEB=true
export MIX_QUIET=1

# Run with Mix output suppressed
exec mix run --no-start --no-deps-check --no-compile --no-halt scripts/launch_mcp.exs

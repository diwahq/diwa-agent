#!/bin/bash
#
# diwa.sh - Startup script for diwa-agent MCP server
#
# This script is used by Claude Desktop to manage the MCP server lifecycle.
# Place in: /Users/ei/codes/diwa-agent/diwa.sh
#
# Usage:
#   ./diwa.sh start    - Start the MCP server (foreground, for Claude Desktop)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Ensure PATH includes Elixir/Mix (asdf, homebrew, or system)
export PATH="$HOME/.asdf/shims:/opt/homebrew/bin:/usr/local/bin:$PATH"

# Standard port for diwa-agent (Not used in Stdio mode, but reserved)
# export PORT="${DIWA_AGENT_PORT:-4000}"

# MIX_ENV for local development
export MIX_ENV="${MIX_ENV:-dev}"

case "$1" in
  start)
    # Claude Desktop calls this - must run in foreground
    # exec replaces shell process with Elixir (proper signal handling)
    # 
    # NOTE: Dependencies must be installed beforehand with: mix deps.get
    # 
    # Mix will automatically start the application, then run the launch script
    # which keeps the process alive.
    # Use the pre-compiled escript for maximum silence and performance
    # This prevents 'mix' from printing any compilation or status messages to stdout
    export DIWA_DISABLE_WEB=true
    export MIX_QUIET=1
    if [ -f "./diwa" ]; then
      exec ./diwa start 2>> /tmp/diwa_mcp_stderr.log
    else
      exec mix run --no-compile scripts/launch_mcp.exs 2>> /tmp/diwa_mcp_stderr.log
    fi
    ;;
    
  *)
    echo "Usage: $0 start"
    echo ""
    echo "This script is designed for Claude Desktop MCP integration."
    echo "The 'start' command runs the server in foreground mode."
    exit 1
    ;;
esac

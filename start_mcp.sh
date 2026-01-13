#!/bin/bash
# start_mcp.sh
export MIX_ENV=dev
export DIWA_DISABLE_WEB=true
cd "$(dirname "$0")"

# Use mix run via diwa.sh instead of escript to avoid NIF loading issues
./diwa.sh start

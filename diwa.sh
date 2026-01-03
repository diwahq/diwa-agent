#!/usr/bin/env bash
# 1. Environment
# Ensure UTF-8 support
export MIX_ENV=${MIX_ENV:-dev}
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export DIWA_DISABLE_WEB=${DIWA_DISABLE_WEB:-true}
export DIWA_DISABLE_TRANSPORT=${DIWA_DISABLE_TRANSPORT:-false}
export DIWA_EDITION=${DIWA_EDITION:-enterprise}

# 2. Navigate to the script's directory
cd "$(dirname "$0")" || exit 1

# 3. Pure Execution
# We use --no-compile to ensure Mix doesn't print any compilation messages.
# If no arguments are passed, default to "start"
ARGS=("$@")
if [ ${#ARGS[@]} -eq 0 ]; then
  ARGS=("start")
fi

# Use 'mix' from PATH instead of hardcoded location
exec mix run --no-halt --no-compile -e "DiwaAgent.CLI.main(System.argv())" -- "${ARGS[@]}"


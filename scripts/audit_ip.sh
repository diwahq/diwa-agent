#!/bin/bash
# IP Audit Script for diwa-agent (Community Edition)
# Verifies that Enterprise-only tools and features have been removed

set -e

echo "🔍 IP Audit - Checking diwa-agent for Enterprise-only code..."
echo "─────────────────────────────────────────────────────────"

FAILED=0
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Patent D1: Health Engine
echo "Checking Patent D1 (Health Engine)..."
if grep "get_context_health()" "$ROOT_DIR/lib/diwa_agent/tools/definitions.ex" | grep -v "^[[:space:]]*#" | grep -v "REMOVED:"; then
    echo "❌ FAILED: get_context_health() still registered"
    FAILED=$((FAILED + 1))
else
    echo "✅ PASS: get_context_health() properly removed"
fi

# Patent D2: ACE (Auto Context Extraction)
echo "Checking Patent D2 (ACE Engine)..."
if grep "run_context_scan()" "$ROOT_DIR/lib/diwa_agent/tools/definitions.ex" | grep -v "^[[:space:]]*#" | grep -v "REMOVED:"; then
    echo "❌ FAILED: run_context_scan() still registered"
    FAILED=$((FAILED + 1))
else
    echo "✅ PASS: run_context_scan() properly removed"
fi

# Patent D3: Conflict Engine
echo "Checking Patent D3 (Conflict Engine)..."
CONFLICT_TOOLS=("list_conflicts" "resolve_conflict" "arbitrate_conflict")
for tool in "${CONFLICT_TOOLS[@]}"; do
    if grep "${tool}()" "$ROOT_DIR/lib/diwa_agent/tools/definitions.ex" | grep -v "^[[:space:]]*#" | grep -v "REMOVED:"; then
        echo "❌ FAILED: ${tool}() still registered"
        FAILED=$((FAILED + 1))
    else
        echo "✅ PASS: ${tool}() properly removed"
    fi
done

# SINAG Runtime Tools
echo "Checking SINAG Runtime Tools..."
SINAG_TOOLS=(
    "register_agent"
    "delegate_task"
    "match_experts"
    "poll_delegated_tasks"
    "respond_to_delegation"
    "complete_delegation"
    "get_agent_health"
    "restore_agent"
    "log_failure"
    "purge_old_checkpoints"
)

for tool in "${SINAG_TOOLS[@]}"; do
    if grep "${tool}()" "$ROOT_DIR/lib/diwa_agent/tools/definitions.ex" | grep -v "^[[:space:]]*#" | grep -v "REMOVED:"; then
        echo "❌ FAILED: ${tool}() still registered"
        FAILED=$((FAILED + 1))
    else
        echo "✅ PASS: ${tool}() properly removed"
    fi
done

# Cluster/Consensus Tools
echo "Checking Cluster/Consensus Tools..."
CLUSTER_TOOLS=("get_cluster_status" "get_byzantine_nodes")
for tool in "${CLUSTER_TOOLS[@]}"; do
    if grep "${tool}()" "$ROOT_DIR/lib/diwa_agent/tools/definitions.ex" | grep -v "^[[:space:]]*#" | grep -v "REMOVED:"; then
        echo "❌ FAILED: ${tool}() still registered"
        FAILED=$((FAILED + 1))
    else
        echo "✅ PASS: ${tool}() properly removed"
    fi
done

# Shortcuts
echo "Checking Shortcuts..."
if grep '"merge".*resolve_conflict' "$ROOT_DIR/lib/diwa_agent/shortcuts/registry.ex" | grep -v "^[[:space:]]*#" | grep -v "REMOVED:"; then
    echo "❌ FAILED: @merge shortcut still registered"
    FAILED=$((FAILED + 1))
else
    echo "✅ PASS: @merge shortcut properly removed"
fi

# Config flag
echo "Checking Config Flag..."
if grep -q "enterprise_features: false" "$ROOT_DIR/config/config.exs"; then
    echo "✅ PASS: enterprise_features flag set to false"
else
    echo "❌ FAILED: enterprise_features flag not set"
    FAILED=$((FAILED + 1))
fi

# Summary
echo "─────────────────────────────────────────────────────────"
if [ $FAILED -eq 0 ]; then
    echo "✅ IP AUDIT PASSED - Safe to release"
    exit 0
else
    echo "❌ IP AUDIT FAILED - $FAILED issue(s) found"
    echo "Cannot release until all Enterprise-only code is removed"
    exit 1
fi

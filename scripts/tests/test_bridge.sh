#!/bin/bash

# Diwa Bridge Tools Verification Script
# This script tests the 10 new coordination tools.

KODA_DB="diwa_test.db"
export KODA_DATABASE_PATH="$KODA_DB"
export KODA_DISABLE_WEB=true

# Clean up
rm -f "$KODA_DB"

echo "🚀 Starting Diwa Bridge Tools Verification..."

# Helper for JSON-RPC calls
call_diwa() {
    local method=$1
    local params=$2
    local id=$3
    echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"method\":\"$method\",\"params\":$params}" | ./diwa.sh start 2>/dev/null | grep "\"id\":$id"
}

# 1. Initialize
echo -e "\n1. Initializing..."
(
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test-bridge","version":"1.0"}}}'
  sleep 0.5
) | ./diwa.sh start > /dev/null 2>&1

# 2. Create Context
echo "2. Creating Context..."
RESULT=$(call_diwa "tools/call" '{"name":"create_context","arguments":{"name":"Bridge Test Project"}}' 2)
CONTEXT_ID=$(echo $RESULT | grep -oE "[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}" | head -n 1)

if [ -z "$CONTEXT_ID" ]; then
    echo "❌ Failed to create context"
    exit 1
fi
echo "✅ Context Created: $CONTEXT_ID"

# 3. Test set_project_status
echo -e "\n3. Testing set_project_status..."
call_diwa "tools/call" "{\"name\":\"set_project_status\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\",\"status\":\"Implementation\",\"completion_pct\":45,\"notes\":\"Working on bridge tools\"}}" 3

# 4. Test get_project_status
echo -e "\n4. Testing get_project_status..."
call_diwa "tools/call" "{\"name\":\"get_project_status\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\"}}" 4

# 5. Test add_requirement
echo -e "\n5. Testing add_requirement..."
REQ_RESULT=$(call_diwa "tools/call" "{\"name\":\"add_requirement\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\",\"title\":\"SQLite JSON support\",\"description\":\"Ensure metadata is queryable via LIKE pattern\",\"priority\":\"High\"}}" 5)
REQ_ID=$(echo $REQ_RESULT | grep -oE "[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}" | tail -n 1)
echo "✅ Requirement ID: $REQ_ID"

# 6. Test mark_requirement_complete
echo -e "\n6. Testing mark_requirement_complete..."
call_diwa "tools/call" "{\"name\":\"mark_requirement_complete\",\"arguments\":{\"requirement_id\":\"$REQ_ID\"}}" 6

# 7. Test record_lesson
echo -e "\n7. Testing record_lesson..."
call_diwa "tools/call" "{\"name\":\"record_lesson\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\",\"title\":\"Metadata Filtering\",\"content\":\"Use LIKE pattern with double quotes for JSON type matching\",\"category\":\"Storage\"}}" 7

# 8. Test search_lessons
echo -e "\n8. Testing search_lessons..."
call_diwa "tools/call" '{"name":"search_lessons","arguments":{"query":"LIKE"}}' 8

# 9. Test flag_blocker
echo -e "\n9. Testing flag_blocker..."
BLOCK_RESULT=$(call_diwa "tools/call" "{\"name\":\"flag_blocker\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\",\"title\":\"NIF loading in escripts\",\"description\":\"Native libraries like exqlite fail to load from escript archive\",\"severity\":\"Critical\"}}" 9)
BLOCK_ID=$(echo $BLOCK_RESULT | grep -oE "[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}" | tail -n 1)
echo "✅ Blocker ID: $BLOCK_ID"

# 10. Test resolve_blocker
echo -e "\n10. Testing resolve_blocker..."
call_diwa "tools/call" "{\"name\":\"resolve_blocker\",\"arguments\":{\"blocker_id\":\"$BLOCK_ID\",\"resolution\":\"Used diwa.sh wrapper script to bypass escript archive limitations\"}}" 10

# 11. Test set_handoff_note
echo -e "\n11. Testing set_handoff_note..."
call_diwa "tools/call" "{\"name\":\"set_handoff_note\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\",\"summary\":\"Completed implementation of 10 bridge tools\",\"next_steps\":[\"Verify with bash script\",\"Update docs\",\"Commit changes\"],\"active_files\":[\"executor.ex\",\"definitions.ex\"]}}" 11

# 12. Test get_active_handoff
echo -e "\n12. Testing get_active_handoff..."
call_diwa "tools/call" "{\"name\":\"get_active_handoff\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\"}}" 12

echo -e "\n🎉 Bridge Tools Verification Complete!"
rm -f "$KODA_DB"

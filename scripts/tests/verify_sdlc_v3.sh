#!/bin/bash

# Diwa SDLC v3 Tools Verification Script
# This script tests the new lifecycle tools and schema enhancements.

KODA_DB="diwa_v3_test.db"
export KODA_DATABASE_PATH="$KODA_DB"
export KODA_DISABLE_WEB=true

# Clean up
rm -f "$KODA_DB"

echo "🚀 Starting Diwa SDLC v3 Tools Verification..."

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
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test-v3","version":"1.0"}}}'
  sleep 0.5
) | ./diwa.sh start > /dev/null 2>&1

# 2. Create Context
echo "2. Creating Context..."
RESULT=$(call_diwa "tools/call" '{"name":"create_context","arguments":{"name":"SDLC Verification Project","description":"Testing SDLC v3 enhancements"}}' 2)
CONTEXT_ID=$(echo $RESULT | grep -oE "[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}" | head -n 1)

if [ -z "$CONTEXT_ID" ]; then
    echo "❌ Failed to create context"
    exit 1
fi
echo "✅ Context Created: $CONTEXT_ID"

# 3. Test add_memory with Actor and Project
echo -e "\n3. Testing add_memory with Actor support..."
call_diwa "tools/call" "{\"name\":\"add_memory\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\",\"content\":\"Initial project architecture\",\"actor\":\"antigravity\",\"project\":\"SDLC-V3\",\"tags\":\"infra,arch\"}}" 3

# 4. Test add_memories (Batch)
echo -e "\n4. Testing add_memories (Batch)..."
call_diwa "tools/call" "{\"name\":\"add_memories\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\",\"memories\":[{\"content\":\"Requirement 1: Multi-user support\",\"actor\":\"human\",\"tags\":\"req\"},{\"content\":\"Requirement 2: API Keys\",\"actor\":\"human\",\"tags\":\"req\"}]}}" 4

# 5. Test record_decision
echo -e "\n5. Testing record_decision..."
call_diwa "tools/call" "{\"name\":\"record_decision\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\",\"decision\":\"Use SQLite for local storage\",\"rationale\":\"Low latency, single-file management, and zero-config deployment.\",\"alternatives\":\"PostgreSQL, Flat JSON files\"}}" 5

# 6. Test record_pattern
echo -e "\n6. Testing record_pattern..."
call_diwa "tools/call" "{\"name\":\"record_pattern\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\",\"name\":\"Context Handoff\",\"description\":\"Always record a handoff note at the end of a session to preserve state.\",\"example\":\"use set_handoff_note with summary and next_steps\"}}" 6

# 7. Test add_requirement (from v2) + prioritize_requirement (new)
echo -e "\n7. Testing Requirement Prioritization..."
REQ_RESULT=$(call_diwa "tools/call" "{\"name\":\"add_requirement\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\",\"title\":\"Security Scan\",\"description\":\"Run Mix Audit on CI\",\"priority\":\"Medium\"}}" 7)
REQ_ID=$(echo $REQ_RESULT | grep -oE "[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}" | tail -n 1)
echo "✅ Requirement ID: $REQ_ID"
call_diwa "tools/call" "{\"name\":\"prioritize_requirement\",\"arguments\":{\"requirement_id\":\"$REQ_ID\",\"priority\":\"High\"}}" 8

# 8. Test record_review
echo -e "\n8. Testing record_review..."
call_diwa "tools/call" "{\"name\":\"record_review\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\",\"title\":\"Schema Upgrade PR\",\"summary\":\"Reviewed the ALTER TABLE logic and data migration safety.\",\"status\":\"approved\",\"external_ref\":\"https://github.com/diwa/pull/42\"}}" 9

# 9. Test record_deployment
echo -e "\n9. Testing record_deployment..."
call_diwa "tools/call" "{\"name\":\"record_deployment\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\",\"environment\":\"staging\",\"version\":\"v3.0.0-beta.1\",\"status\":\"success\",\"external_ref\":\"https://ci.diwa.dev/build/12345\"}}" 10

# 10. Test log_incident
echo -e "\n10. Testing log_incident..."
call_diwa "tools/call" "{\"name\":\"log_incident\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\",\"title\":\"Migration Timeout\",\"description\":\"Large datasets caused ALTER TABLE to timeout on ARM64 nodes.\",\"severity\":\"moderate\",\"external_ref\":\"https://monitoring.diwa.dev/incident/55\"}}" 11

# 11. Test record_analysis_result
echo -e "\n11. Testing record_analysis_result..."
call_diwa "tools/call" "{\"name\":\"record_analysis_result\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\",\"scanner_name\":\"Mix Audit\",\"findings\":\"No vulnerable dependencies found.\",\"severity\":\"info\"}}" 12

# 12. Test Knowledge Graph Linking (Hierarchy)
echo -e "\n12. Testing Knowledge Graph Linking..."
# Parent: Requirement 1
# Child: Decision 1
REQ_ID_1=$(call_diwa "tools/call" "{\"name\":\"list_by_tag\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\",\"tag\":\"req\"}}" 13 | grep -oE "[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}" | head -n 1)
DEC_ID_1=$(call_diwa "tools/call" "{\"name\":\"list_by_tag\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\",\"tag\":\"decision\"}}" 14 | grep -oE "[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}" | head -n 1)

echo "🔗 Linking Decision ($DEC_ID_1) to Requirement ($REQ_ID_1)"
call_diwa "tools/call" "{\"name\":\"link_memories\",\"arguments\":{\"parent_id\":\"$REQ_ID_1\",\"child_id\":\"$DEC_ID_1\"}}" 15

# 13. Test get_memory_tree
echo -e "\n13. Testing get_memory_tree..."
call_diwa "tools/call" "{\"name\":\"get_memory_tree\",\"arguments\":{\"root_id\":\"$REQ_ID_1\"}}" 16

# 14. Test list_by_tag (filtering by 'incident')
echo -e "\n14. Testing list_by_tag (filtering by 'incident')..."
call_diwa "tools/call" "{\"name\":\"list_by_tag\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\",\"tag\":\"incident\"}}" 17

# 15. Test export_context (Markdown)
echo -e "\n15. Testing export_context (Markdown)..."
call_diwa "tools/call" "{\"name\":\"export_context\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\",\"format\":\"markdown\"}}" 18 | grep -o "Export: SDLC Verification Project"

# 16. Test export_context (JSON)
echo -e "\n16. Testing export_context (JSON)..."
EXPORT_JSON=$(call_diwa "tools/call" "{\"name\":\"export_context\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\",\"format\":\"json\"}}" 19)
echo $EXPORT_JSON | grep -o "\"exported_at\"" > /dev/null && echo "✅ JSON Export contains metadata"

echo -e "\n🎉 SDLC v3 Tools Verification Complete!"
rm -f "$KODA_DB"

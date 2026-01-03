#!/usr/bin/env bash
# Comprehensive test script for Diwa MCP Server (using mix run)

set -e  # Exit on error

echo "════════════════════════════════════════════════════════"
echo " Diwa MCP Server - Comprehensive Test"
echo "════════════════════════════════════════════════════════"
echo ""

# Clean up old database
echo "→ Cleaning up old test database..."
rm -rf ~/.diwa/diwa.db 2>/dev/null || true
echo ""

# Helper function to run a test
run_test() {
  local name="$1"
  local request="$2"
  
  echo "→ Test: $name"
  echo "─────────────────────────────────────────────────────"
  
  # Send initialize + the actual request
  (
    echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
    sleep 0.2
    echo "$request"
    sleep 0.3
  ) | timeout 3 mix run --no-halt -e 'Diwa.CLI.main(["start"])' 2>/dev/null | \
      grep "jsonrpc" | tail -1 | python3 -c "
import sys, json
try:
  data = json.load(sys.stdin)
  if 'result' in data and 'content' in data['result']:
    for item in data['result']['content']:
      if 'text' in item:
        print(item['text'])
  else:
    print(json.dumps(data, indent=2))
except:
  pass
"
  echo ""
}

echo "════════════════════════════════════════════════════════"
echo " CONTEXT TESTS"
echo "════════════════════════════════════════════════════════"
echo ""

# Test 1: Create Context
run_test "create_context" \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"create_context","arguments":{"name":"My Project","description":"A development project"}}}'

# Test 2: List Contexts
run_test "list_contexts" \
  '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"list_contexts","arguments":{}}}'

# Get context ID from database
CONTEXT_ID=$(sqlite3 ~/.diwa/diwa.db "SELECT id FROM contexts LIMIT 1" 2>/dev/null || echo "")

if [ -n "$CONTEXT_ID" ]; then
  echo "✓ Found context ID: $CONTEXT_ID"
  echo ""
  
  # Test 3: Get Context
  run_test "get_context" \
    "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"tools/call\",\"params\":{\"name\":\"get_context\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\"}}}"
  
  # Test 4: Update Context
  run_test "update_context" \
    "{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"tools/call\",\"params\":{\"name\":\"update_context\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\",\"name\":\"Updated Project\",\"description\":\"New description\"}}}"
  
  echo "════════════════════════════════════════════════════════"
  echo " MEMORY TESTS"
  echo "════════════════════════════════════════════════════════"
  echo ""
  
  # Test 5: Add Memory
  run_test "add_memory" \
    "{\"jsonrpc\":\"2.0\",\"id\":6,\"method\":\"tools/call\",\"params\":{\"name\":\"add_memory\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\",\"content\":\"This is a test memory with important information\"}}}"
  
  # Test 6: Add Another Memory  
  run_test "add_memory_2" \
    "{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":\"tools/call\",\"params\":{\"name\":\"add_memory\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\",\"content\":\"Another memory for testing search functionality\"}}}"
  
  # Test 7: List Memories
  run_test "list_memories" \
    "{\"jsonrpc\":\"2.0\",\"id\":8,\"method\":\"tools/call\",\"params\":{\"name\":\"list_memories\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\"}}}"
  
  # Get memory ID
  MEMORY_ID=$(sqlite3 ~/.diwa/diwa.db "SELECT id FROM memories LIMIT 1" 2>/dev/null || echo "")
  
  if [ -n "$MEMORY_ID" ]; then
    echo "✓ Found memory ID: $MEMORY_ID"
    echo ""
    
    # Test 8: Get Memory
    run_test "get_memory" \
      "{\"jsonrpc\":\"2.0\",\"id\":9,\"method\":\"tools/call\",\"params\":{\"name\":\"get_memory\",\"arguments\":{\"memory_id\":\"$MEMORY_ID\"}}}"
    
    # Test 9: Update Memory
    run_test "update_memory" \
      "{\"jsonrpc\":\"2.0\",\"id\":10,\"method\":\"tools/call\",\"params\":{\"name\":\"update_memory\",\"arguments\":{\"memory_id\":\"$MEMORY_ID\",\"content\":\"Updated memory content\"}}}"
    
    # Test 10: Delete Memory
    run_test "delete_memory" \
      "{\"jsonrpc\":\"2.0\",\"id\":11,\"method\":\"tools/call\",\"params\":{\"name\":\"delete_memory\",\"arguments\":{\"memory_id\":\"$MEMORY_ID\"}}}"
  fi
  
  # Test 11: Delete Context
  run_test "delete_context" \
    "{\"jsonrpc\":\"2.0\",\"id\":12,\"method\":\"tools/call\",\"params\":{\"name\":\"delete_context\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\"}}}"
fi

echo "════════════════════════════════════════════════════════"
echo " SUMMARY"
echo "════════════════════════════════════════════════════════"
echo ""

# Check final database state
if [ -f ~/.diwa/diwa.db ]; then
  echo "Database statistics:"
  echo "  Contexts: $(sqlite3 ~/.diwa/diwa.db "SELECT COUNT(*) FROM contexts" 2>/dev/null || echo "0")"
  echo "  Memories: $(sqlite3 ~/.diwa/diwa.db "SELECT COUNT(*) FROM memories" 2>/dev/null || echo "0")"
else
  echo "⚠  Database not found"
fi

echo ""
echo "✓ All tests complete!"

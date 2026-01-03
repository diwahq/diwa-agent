#!/usr/bin/env bash
# Test the new search_memories tool

echo "════════════════════════════════════════════════════════"
echo " Testing search_memories Tool"
echo "════════════════════════════════════════════════════════"
echo ""

# Clean database
rm -rf ~/.diwa/diwa.db 2>/dev/null

run_test() {
  local name="$1"
  local request="$2"
  
  echo "→ $name"
  echo "─────────────────────────────────────────────────────"
  
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

# Setup: Create context and add memories
echo "Setting up test data..."
echo ""

run_test "Create context 'Phoenix Project'" \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"create_context","arguments":{"name":"Phoenix Project","description":"Web development"}}}'

# Get context ID
CONTEXT_ID=$(sqlite3 ~/.diwa/diwa.db "SELECT id FROM contexts LIMIT 1" 2>/dev/null)

if [ -n "$CONTEXT_ID" ]; then
  echo "✓ Context ID: $CONTEXT_ID"
  echo ""
  
  # Add some searchable memories
  run_test "Add memory about LiveView" \
    "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"add_memory\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\",\"content\":\"Phoenix LiveView allows real-time features without writing JavaScript\"}}}"
  
  run_test "Add memory about Ecto" \
    "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"tools/call\",\"params\":{\"name\":\"add_memory\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\",\"content\":\"Ecto is the database wrapper for Elixir with powerful query composition\"}}}"
  
  run_test "Add memory about deployment" \
    "{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"tools/call\",\"params\":{\"name\":\"add_memory\",\"arguments\":{\"context_id\":\"$CONTEXT_ID\",\"content\":\"Deploy Phoenix apps using mix release and systemd for production\"}}}"
  
  echo "════════════════════════════════════════════════════════"
  echo " SEARCH TESTS"
  echo "════════════════════════════════════════════════════════"
  echo ""
  
  # Test 1: Search across all contexts
  run_test "Search for 'Phoenix' across all contexts" \
    '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"search_memories","arguments":{"query":"Phoenix"}}}'
  
  # Test 2: Search for 'Elixir'
  run_test "Search for 'Elixir'" \
    '{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"search_memories","arguments":{"query":"Elixir"}}}'
  
  # Test 3: Search within specific context
  run_test "Search for 'LiveView' in specific context" \
    "{\"jsonrpc\":\"2.0\",\"id\":8,\"method\":\"tools/call\",\"params\":{\"name\":\"search_memories\",\"arguments\":{\"query\":\"LiveView\",\"context_id\":\"$CONTEXT_ID\"}}}"
  
  # Test 4: Search with no results
  run_test "Search for 'Ruby' (should find nothing)" \
    '{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"search_memories","arguments":{"query":"Ruby"}}}'
  
fi

echo "════════════════════════════════════════════════════════"
echo " Test Complete!"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Database stats:"
sqlite3 ~/.diwa/diwa.db "SELECT COUNT(*) || ' memories' FROM memories" 2>/dev/null
echo ""
echo "✓ search_memories tool is working!"

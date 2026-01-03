#!/usr/bin/env bash
# Test Diwa using mix run (supports native dependencies like exqlite)

echo "════════════════════════════════════════════════════════"
echo " Testing Diwa MCP Server (via mix run)"
echo "════════════════════════════════════════════════════════"
echo ""

# Test 1: Initialize
echo "→ Test 1: Initialize MCP server"
echo "─────────────────────────────────────────────────────────"
echo '{" jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | timeout 2 mix run --no-halt -e 'Diwa.CLI.main(["start"])' 2>/dev/null | grep "jsonrpc" | tail -1 | python3 -m json.tool 2>/dev/null
echo ""

# Test 2: Create Context
echo "→ Test 2: Create a context"
echo "─────────────────────────────────────────────────────────"
(
  echo '{" jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
  sleep 0.3
  echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"create_context","arguments":{"name":"Test Project","description":"A test project"}}}'
  sleep 0.5
) | timeout 3 mix run --no-halt -e 'Diwa.CLI.main(["start"])' 2>/dev/null | grep "jsonrpc" | tail -1 | python3 -m json.tool 2>/dev/null
echo ""

# Test 3: List Contexts
echo "→ Test 3: List contexts"
echo "─────────────────────────────────────────────────────────"
(
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
  sleep 0.3
  echo '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"list_contexts","arguments":{}}}'
  sleep 0.5
) | timeout 3 mix run --no-halt -e 'Diwa.CLI.main(["start"])' 2>/dev/null | grep "jsonrpc" | tail -1 | python3 -m json.tool 2>/dev/null
echo ""

echo "✓ Quick tests complete!"
echo ""
echo "Note: For full testing, run ./test_full_mix.sh"

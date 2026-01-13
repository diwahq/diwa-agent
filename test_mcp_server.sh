#!/bin/bash
# test_mcp_server.sh - Diagnostic script for testing MCP server

set -e

echo "=== Diwa MCP Server Diagnostic Test ==="
echo ""

cd "$(dirname "$0")"

echo "1. Testing server initialization..."
response=$(echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | timeout 10 ./diwa.sh start 2>/dev/null | head -1)

if [ -z "$response" ]; then
  echo "❌ FAILED: No response from server"
  exit 1
fi

echo "✅ Server responded"
echo "Response: $response"
echo ""

# Validate JSON
if echo "$response" | jq . >/dev/null 2>&1; then
  echo "✅ Valid JSON response"
else
  echo "❌ FAILED: Invalid JSON"
  exit 1
fi

# Check if it's a valid initialize response
if echo "$response" | jq -e '.result.serverInfo.name == "diwa"' >/dev/null 2>&1; then
  echo "✅ Server initialized correctly"
else
  echo "❌ FAILED: Invalid initialize response"
  exit 1
fi

echo ""
echo "=== All tests passed! ==="
echo "The MCP server is ready for use with Claude and Antigravity."

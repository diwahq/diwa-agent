#!/usr/bin/env bash

# Test script for Diwa MCP server
# This sends JSON-RPC messages to test the protocol

echo "Testing Diwa MCP Server"
echo "======================="
echo ""

# Test 1: Initialize
echo "Test 1: Initialize request"
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test-client","version":"1.0.0"}}}' | ./diwa start &
PID=$!
sleep 2
kill $PID 2>/dev/null
echo ""

# Test 2: Tools list
echo "Test 2: Tools list request"
(
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test-client","version":"1.0.0"}}}'
  sleep 0.5
  echo '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
  sleep 0.5
) | timeout 3 ./diwa start 2>/dev/null
echo ""

echo "Tests completed!"

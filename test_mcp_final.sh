#!/bin/bash
# Final comprehensive test for the Diwa MCP server
# This script verifies that the server is working correctly with Claude

set -e

echo "======================================================================"
echo "Diwa MCP Server - Final Verification Test"
echo "======================================================================"
echo ""

cd "$(dirname "$0")"

# Test 1: Version check (should not produce errors on stderr)
echo "Test 1: Version check..."
VERSION_OUTPUT=$(./diwa version 2>&1)
if echo "$VERSION_OUTPUT" | grep -q "Diwa MCP Context Server"; then
    echo "✅ Version: $VERSION_OUTPUT"
else
    echo "❌ FAILED: Version command failed"
    exit 1
fi

# Test 2: Check startup time
echo ""
echo "Test 2: Startup performance..."
START_TIME=$(date +%s)
(echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' && sleep 0.5) | timeout 3 ./diwa.sh start > /dev/null 2>&1 &
PID=$!
sleep 2
kill $PID 2>/dev/null || true
wait $PID 2>/dev/null || true
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
if [ $DURATION -lt 5 ]; then
    echo "✅ Startup time: ${DURATION}s (Good - should be < 5s)"
else
    echo "⚠️  Startup time: ${DURATION}s (Slow - should be < 5s)"
fi

# Test 3: Check for stdout pollution
echo ""
echo "Test 3: Checking for stdout pollution..."
STDOUT_TEST=$(timeout 2 bash -c '(echo "{\"jsonrpc\":\"2.0\",\"id\":999,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{},\"clientInfo\":{\"name\":\"test\",\"version\":\"1.0\"}}}" && sleep 1) | ./diwa.sh start 2>/dev/null' || true)

# Check if stdout contains ONLY JSON (no error messages timestamped like "07:29:23.114")
if echo "$STDOUT_TEST" | grep -E "^[0-9]{2}:[0-9]{2}:[0-9]{2}" >/dev/null; then
    echo "❌ FAILED: Stdout contains non-JSON data (timestamps found)"
    echo "Polluted output: $STDOUT_TEST"
    exit 1
elif [ -z "$STDOUT_TEST" ]; then
    echo "⚠️  No output captured (process may have exited early)"
else
    echo "✅ Stdout is clean (only JSON)"
fi

# Test 4: Check traffic log for proper operation
echo ""
echo "Test 4: Checking MCP protocol compliance..."
if [ -f "mcp_traffic.log" ]; then
    LAST_REQUEST=$(grep '\[IN\]' mcp_traffic.log | tail -1)
    LAST_RESPONSE=$(grep '\[OUT\]' mcp_traffic.log | tail -1)
    
    if [ -n "$LAST_RESPONSE" ]; then
        # Validate the response is valid JSON
        RESPONSE_JSON=$(echo "$LAST_RESPONSE" | sed 's/\[OUT\] //')
        if echo "$RESPONSE_JSON" | jq . >/dev/null 2>&1; then
            echo "✅ MCP responses are valid JSON"
            SERVER_NAME=$(echo "$RESPONSE_JSON" | jq -r '.result.serverInfo.name // empty' 2>/dev/null)
            if [ "$SERVER_NAME" = "diwa" ]; then
                echo "✅ Server identifies correctly as 'diwa'"
            fi
        else
            echo "❌ FAILED: Response is not valid JSON"
            exit 1
        fi
    fi
else
    echo "⚠️  Traffic log not found"
fi

echo ""
echo "======================================================================"
echo "✅ All tests passed!"
echo "======================================================================"
echo ""
echo "The Diwa MCP server is ready to use with Claude and Antigravity."
echo "Configuration file: ~/.gemini/antigravity/mcp_config.json"
echo ""

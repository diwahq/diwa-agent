#!/usr/bin/env bash
# Simple end-to-end test for Diwa

echo "════════════════════════════════════════════════════════"
echo " Diwa E2E Test"
echo "════════════════════════════════════════════════════════"
echo ""

# Clean database
rm -rf ~/.diwa/diwa.db 2>/dev/null || true

# Start server in background and send test requests
(
  sleep 0.5
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
  sleep 0.5
  echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"create_context","arguments":{"name":"Test Project","description":"A test"}}}'
  sleep 0.5
  echo '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"list_contexts","arguments":{}}}'
  sleep 0.5
) | mix run --no-halt -e 'Diwa.CLI.main(["start"])' 2>&1 | tee /tmp/diwa_test.log

echo ""
echo "════════════════════════════════════════════════════════"
echo " Database Check"
echo "════════════════════════════════════════════════════════"

if [ -f ~/.diwa/diwa.db ]; then
  echo "✓ Database created successfully"
  echo ""
  echo "Contexts:"
  sqlite3 ~/.diwa/diwa.db "SELECT id, name, description FROM contexts" 2>/dev/null || echo "  (none)"
  echo ""
  echo "Stats:"
  echo "  Contexts: $(sqlite3 ~/.diwa/diwa.db "SELECT COUNT(*) FROM contexts" 2>/dev/null)"
  echo "  Memories: $(sqlite3 ~/.diwa/diwa.db "SELECT COUNT(*) FROM memories" 2>/dev/null)"
else
  echo "✗ Database not found"
fi

echo ""
echo "✓ Test complete!"

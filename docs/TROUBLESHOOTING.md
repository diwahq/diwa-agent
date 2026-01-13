# MCP Server Troubleshooting Guide

## Common Issues

### 1. "Bad escaped character in JSON" Error

**Symptom**: Claude Desktop shows error: `Bad escaped character in JSON at position XX`

**Cause**: The MCP server is sending JSON with improperly escaped characters.

**Solution**: 
- ✅ **FIXED** in commit [current] - Updated `DiwaAgent.Transport.Stdio` to use `escape: :unicode_safe`
- The server now properly escapes all special characters and Unicode

**Verification**:
```bash
cd /Users/ei/codes/diwa-agent
mix compile
# Restart Claude Desktop to pick up the new version
```

**If issue persists**:
1. Check stderr logs: `tail -f ~/.diwa/logs/mcp_server.log` (if logging is enabled)
2. Look for error messages with response IDs
3. The debug logs will show which tool execution is causing the issue

### 2. MCP Server Won't Start

**Symptom**: Claude Desktop can't connect to the MCP server

**Diagnosis**:
```bash
cd /Users/ei/codes/diwa-agent
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | ./diwa.sh start
```

**Expected output**: Should see a JSON response with `"result"` containing server info

**Common causes**:
- Dependencies not installed: Run `mix deps.get`
- Compilation errors: Run `mix compile` and fix any errors
- Database not initialized: Run `mix ecto.migrate`

### 3. Tool Execution Fails

**Symptom**: Tools return errors or don't execute

**Diagnosis**:
1. Check if the context exists: Use `list_contexts` tool
2. Verify tool parameters are correct
3. Check edition restrictions (some tools require Enterprise edition)

**Debug mode**:
```bash
# Run with debug logging
MIX_ENV=dev LOG_LEVEL=debug ./diwa.sh start
```

### 4. Database Issues

**Symptom**: Errors mentioning SQLite or Ecto

**Solution**:
```bash
cd /Users/ei/codes/diwa-agent
mix ecto.reset  # WARNING: This deletes all data!
# Or for production:
mix ecto.migrate
```

## Logging

### Enable Debug Logging
Edit `config/dev.exs`:
```elixir
config :logger, level: :debug
```

### Log Locations
- **Stderr**: All error messages go to stderr (visible in Claude Desktop logs)
- **Custom logs**: Can be configured in `config/dev.exs`

## Testing the MCP Server

### Quick Test Script
```bash
#!/bin/bash
cd /Users/ei/codes/diwa-agent

# Test initialize
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | ./diwa.sh start 2>&1 | head -5
```

### Full Integration Test
```bash
# Create test input
cat > /tmp/mcp_test.jsonl << 'EOF'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/list"}
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"list_contexts","arguments":{}}}
EOF

timeout 5 ./diwa.sh start < /tmp/mcp_test.jsonl 2>/dev/null | python3 -m json.tool
```

## Getting Help

1. **Check the logs**: Look for error messages in stderr
2. **Verify JSON**: All responses should be valid JSON
3. **Test manually**: Use the test scripts above to isolate issues
4. **Check edition**: Some features require Enterprise edition

## Recent Fixes

- **2026-01-06**: Fixed "Bad escaped character in JSON" error by using `escape: :unicode_safe` in Jason encoder

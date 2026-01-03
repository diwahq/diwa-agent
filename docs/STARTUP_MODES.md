# Diwa Startup Modes

**Understanding the difference between MCP mode and Full mode**

---

## 🎯 Two Ways to Run Diwa

Diwa can run in two different modes depending on your use case:

1. **MCP Mode** - For Claude Desktop integration (lightweight, no web UI)
2. **Full Mode** - For development and monitoring (includes web dashboard)

---

## 📋 Mode Comparison

| Feature | MCP Mode | Full Mode |
|---------|----------|-----------|
| **Command** | `./diwa.sh start` | `mix run --no-halt` |
| **MCP Server** | ✅ Yes | ✅ Yes |
| **STDIO Transport** | ✅ Yes | ✅ Yes |
| **Web Dashboard** | ❌ No | ✅ Yes (port 4000) |
| **Database** | ✅ PostgreSQL | ✅ PostgreSQL |
| **Claude Desktop** | ✅ Optimized | ✅ Works |
| **Browser Access** | ❌ No | ✅ Yes |
| **Memory Usage** | Lower (~50MB) | Higher (~100MB) |
| **Port 4000** | Not used | Required |

---

## 🔧 MCP Mode (Claude Desktop)

### Start Command
```bash
./diwa.sh start
```

### What Starts
- ✅ PostgreSQL Repo (database connection)
- ✅ MCP Server (JSON-RPC protocol handler)
- ✅ SSE Registry (for Server-Sent Events)
- ✅ STDIO Transport (reads/writes JSON-RPC via stdin/stdout)
- ❌ Web Dashboard (disabled via `DIWA_DISABLE_WEB=true`)

### Environment Variables
```bash
export DIWA_DISABLE_WEB=true        # Disables web dashboard
export DIWA_DISABLE_TRANSPORT=false # Enables STDIO transport
export MIX_ENV=dev
```

### Use Cases
- ✅ Claude Desktop integration
- ✅ Production deployment
- ✅ Headless server environments
- ✅ When port 4000 is unavailable
- ✅ Minimal resource usage

### How It Works
```bash
# diwa.sh executes:
mix run --no-halt --no-compile -e "Diwa.CLI.main(['start'])"
```

The `Diwa.CLI.main/1` function:
1. Calls `Application.ensure_all_started(:diwa)`
2. Starts supervision tree with MCP components
3. Skips web server (DIWA_DISABLE_WEB=true)
4. Sleeps forever (`Process.sleep(:infinity)`)

---

## 🌐 Full Mode (Development & Monitoring)

### Start Command
```bash
mix run --no-halt
```

Or with Phoenix server:
```bash
mix phx.server
```

### What Starts
- ✅ PostgreSQL Repo (database connection)
- ✅ MCP Server (JSON-RPC protocol handler)
- ✅ SSE Registry (for Server-Sent Events)
- ✅ STDIO Transport (reads/writes JSON-RPC)
- ✅ Web Dashboard (Bandit web server on port 4000)

### Environment Variables
```bash
# DIWA_DISABLE_WEB not set (defaults to false)
export MIX_ENV=dev
```

### Use Cases
- ✅ Local development
- ✅ Visual monitoring via dashboard
- ✅ Debugging and testing
- ✅ Viewing context health scores
- ✅ Searching memories via web UI

### Access Points
- **Dashboard**: http://localhost:4000/dashboard
- **Search**: http://localhost:4000/search?q=query
- **SSE Endpoint**: http://localhost:4000/sse
- **MCP Endpoint**: http://localhost:4000/message

---

## 🎬 Recommended Workflows

### Workflow 1: Claude Desktop Only
```bash
# Claude Desktop config uses ./diwa.sh
# Diwa starts automatically when Claude Desktop launches
# No manual startup needed
```

### Workflow 2: Development with Dashboard
```bash
# Terminal 1: Start Diwa with dashboard
mix run --no-halt

# Browser: Open dashboard
open http://localhost:4000/dashboard

# Terminal 2: Run tests or interact via CLI
mix test
```

### Workflow 3: Both Simultaneously
```bash
# Terminal 1: Start Diwa with dashboard for monitoring
mix run --no-halt

# Claude Desktop: Uses ./diwa.sh (separate instance)
# Both share the same PostgreSQL database
# Changes in Claude appear in the dashboard!
```

**Note**: Running both modes simultaneously is safe because:
- They use the same PostgreSQL database
- MCP mode doesn't bind to port 4000
- STDIO transport doesn't conflict with web server
- Ecto connection pool handles concurrent access

---

## 🔍 Under the Hood

### Application Startup (`lib/diwa/application.ex`)

```elixir
def start(_type, _args) do
  children = [
    Diwa.Repo,                    # Always starts
    Diwa.Server,                  # Always starts
    {Registry, keys: :unique, name: Diwa.SSERegistry}  # Always starts
  ]

  # Add STDIO transport unless disabled
  children = if System.get_env("DIWA_DISABLE_TRANSPORT") == "true" do
    children
  else
    children ++ [Diwa.Protocol.Transport]  # For MCP communication
  end

  # Add web server only if not disabled
  children = if System.get_env("DIWA_DISABLE_WEB") == "true" do
    children  # Skip web server
  else
    children ++ [{Bandit, plug: Diwa.Web.Router, port: 4000}]  # Add web server
  end

  Supervisor.start_link(children, opts)
end
```

### Key Environment Variables

| Variable | Default | Effect |
|----------|---------|--------|
| `DIWA_DISABLE_WEB` | `false` | When `true`, skips web server startup |
| `DIWA_DISABLE_TRANSPORT` | `false` | When `true`, skips STDIO transport |
| `MIX_ENV` | `dev` | Elixir environment (dev/test/prod) |
| `PORT` | `4000` | Web server port (when enabled) |

---

## 🐛 Troubleshooting

### Issue: Port 4000 already in use

**Solution 1**: Use MCP mode (no web server)
```bash
./diwa.sh start
```

**Solution 2**: Kill process on port 4000
```bash
lsof -i :4000 -t | xargs kill -9
```

**Solution 3**: Change port
```bash
PORT=4001 mix run --no-halt
```

### Issue: Multiple Diwa instances running

**Check running instances**:
```bash
ps aux | grep -E "diwa|mix run" | grep -v grep
```

**Stop all instances**:
```bash
pkill -f "mix run --no-halt"
pkill -f "diwa.sh"
```

### Issue: Too many PostgreSQL connections

**Cause**: Multiple Diwa instances with connection pools

**Solution**: Stop extra instances
```bash
# Check connections
ps aux | grep "postgres.*idle" | wc -l

# Stop Diwa instances
pkill -f "mix run"

# Connections will close automatically
```

---

## 📊 Performance Considerations

### Connection Pooling

Both modes use Ecto connection pooling:
- **Default pool size**: 10 connections
- **Per instance**: Each Diwa instance gets its own pool
- **Total connections**: (Number of instances) × 10

**Example**:
- 1 instance = 10 PostgreSQL connections
- 2 instances = 20 PostgreSQL connections
- 3 instances = 30 PostgreSQL connections

### Memory Usage

| Component | Memory |
|-----------|--------|
| Elixir VM (BEAM) | ~30MB |
| PostgreSQL connections (10) | ~5MB |
| MCP Server | ~5MB |
| Web Server (Bandit) | ~10MB |
| **MCP Mode Total** | ~50MB |
| **Full Mode Total** | ~100MB |

---

## 🎯 Best Practices

### For Development
1. Use **Full Mode** (`mix run --no-halt`)
2. Keep dashboard open for monitoring
3. Use `mix test` in separate terminal
4. Restart when changing config

### For Claude Desktop
1. Use **MCP Mode** (`./diwa.sh start`)
2. Let Claude Desktop manage the process
3. Don't start manually (Claude does it)
4. Check logs if issues: `~/Library/Logs/Claude/mcp*.log`

### For Production
1. Use **MCP Mode** with proper supervision
2. Consider using `mix release` for deployment
3. Set appropriate pool size in config
4. Monitor PostgreSQL connections

---

## 📝 Configuration Files

### Claude Desktop Config
```json
{
  "mcpServers": {
    "diwa": {
      "command": "/absolute/path/to/diwa/diwa.sh",
      "args": ["start"]
    }
  }
}
```

### Ecto Pool Configuration (`config/dev.exs`)
```elixir
config :diwa, Diwa.Repo,
  username: "postgres",
  password: "postgres_password",
  hostname: "localhost",
  database: "diwa_dev",
  pool_size: 10  # Adjust based on load
```

---

## 🔗 Related Documentation

- [USAGE.md](../USAGE.md) - General usage guide
- [QUICKREF.md](../QUICKREF.md) - Quick reference
- [CLAUDE_DESKTOP_QUICKSTART.md](../CLAUDE_DESKTOP_QUICKSTART.md) - Claude integration
- [.agent/claude_desktop_integration_testing.md](.agent/claude_desktop_integration_testing.md) - Testing guide

---

**Last Updated**: December 26, 2025  
**Diwa Version**: 2.0.0-beta

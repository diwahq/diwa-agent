# Claude Desktop MCP Setup Guide

> **For diwa-agent — AI Memory & Context Management**

This guide sets up Claude Desktop to run **diwa-agent** as a local MCP server, giving you access to context detection, memory management, and relationship linking tools.

---

## What You Get

Once configured, Claude Desktop will have access to:

| Tool | Description |
|------|-------------|
| `detect_context` | Auto-detect project context from directory/git |
| `bind_context` | Bind a context to a directory path |
| `unbind_context` | Remove a directory binding |
| `list_bindings` | Show all directory bindings |
| `link_contexts` | Create relationships between contexts |
| `unlink_contexts` | Remove relationships |
| `get_related_contexts` | Query context relationships |
| `create_context` | Create a new project context |
| `add_memory` | Add memory/notes to a context |
| `search_memories` | Search across all memories |
| `set_handoff_note` | Create session handoff for continuity |
| `get_resume_context` | Resume from previous session |
| ... | And 40+ more tools |

---

## Prerequisites

- [x] **Elixir/OTP** installed (via [asdf](https://asdf-vm.com/) or homebrew)
- [x] **PostgreSQL** running locally
- [x] **Claude Desktop** app installed ([download](https://claude.ai/download))
- [x] **diwa-agent** repo cloned

---

## Step 1: Clone and Setup diwa-agent

```bash
# Clone the repo
git clone https://github.com/diwahq/diwa-agent.git
cd diwa-agent

# Install dependencies
mix deps.get

# Create and migrate database
mix ecto.create
mix ecto.migrate
```

---

## Step 2: Create Startup Script

Create `diwa.sh` in the repo root:

```bash
#!/bin/bash
#
# diwa.sh - Startup script for diwa-agent MCP server
#
# Used by Claude Desktop to manage the MCP server lifecycle.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Ensure PATH includes Elixir/Mix
export PATH="$HOME/.asdf/shims:/opt/homebrew/bin:/usr/local/bin:$PATH"

# Standard port for diwa-agent
export PORT="${DIWA_AGENT_PORT:-4000}"

# MIX_ENV for local development
export MIX_ENV="${MIX_ENV:-dev}"

case "$1" in
  start)
    exec mix run --no-halt
    ;;
  *)
    echo "Usage: $0 start"
    exit 1
    ;;
esac
```

Make it executable:

```bash
chmod +x diwa.sh
```

---

## Step 3: Test the Server

Verify diwa-agent starts correctly:

```bash
./diwa.sh start
```

You should see Phoenix starting on port 4000. Press `Ctrl+C` to stop.

---

## Step 4: Configure Claude Desktop

### Open Configuration

1. Open **Claude Desktop**
2. Go to **Settings** (gear icon or `Cmd + ,`)
3. Click **Developer** in the left sidebar
4. Click **Edit Config**

### Add diwa-agent

Add the following to your config file:

```json
{
  "mcpServers": {
    "diwa": {
      "command": "/path/to/diwa-agent/diwa.sh",
      "args": ["start"]
    }
  }
}
```

**Important:** Replace `/path/to/diwa-agent` with your actual path, e.g.:
- macOS: `/Users/yourname/codes/diwa-agent/diwa.sh`
- Linux: `/home/yourname/codes/diwa-agent/diwa.sh`

Save and close the config.

---

## Step 5: Restart Claude Desktop

**Important:** You must fully quit and reopen Claude Desktop.

1. Press **Cmd + Q** (not just close the window)
2. Reopen Claude Desktop
3. Go to **Settings → Developer**
4. Verify the server shows **"running"**

```
┌─────────────────────────────────┐
│ Local MCP servers               │
├─────────────────────────────────┤
│ diwa    [running]               │
└─────────────────────────────────┘
```

---

## Step 6: Verify Setup

### Check Port

```bash
lsof -i :4000 | grep LISTEN
```

Should show the BEAM (Erlang VM) process listening.

### Test in Claude Desktop

Try these commands in a Claude conversation:

```
"Create a new context called 'My Project'"
→ Creates a context ✓

"Add a memory: We decided to use PostgreSQL for storage"
→ Adds memory to context ✓

"What do you remember about this project?"
→ Retrieves memories ✓
```

---

## Configuration

### Port

Default port is `4000`. To change:

```bash
export DIWA_AGENT_PORT=4001
./diwa.sh start
```

Or set in `config/dev.exs`:

```elixir
config :diwa_agent, DiwaAgentWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000]
```

### Database

Database connection is configured in `config/dev.exs`:

```elixir
config :diwa_agent, DiwaAgent.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "diwa_agent_dev",
  port: 5432
```

Adjust to match your PostgreSQL setup.

---

## Troubleshooting

### Server Not Starting

**Check Elixir is installed:**
```bash
elixir --version
mix --version
```

**Check dependencies:**
```bash
cd /path/to/diwa-agent
mix deps.get
mix compile
```

**Try running manually:**
```bash
cd /path/to/diwa-agent
mix run --no-halt
```

### Port Already in Use

```bash
# Find what's using port 4000
lsof -i :4000

# Kill the process (if safe)
kill -9 <PID>

# Or use a different port
export DIWA_AGENT_PORT=4001
```

### Database Connection Failed

```bash
# Check PostgreSQL is running
pg_isready

# Create database if missing
createdb diwa_agent_dev

# Run migrations
mix ecto.migrate
```

### Tools Not Appearing in Claude

1. Ensure server shows "running" in Developer settings
2. Fully quit Claude Desktop (Cmd+Q) and reopen
3. Check Console.app for errors (search "Claude")
4. Verify the path in config is correct and absolute

### Config File Location

The Claude Desktop config file is located at:

```
~/Library/Application Support/Claude/claude_desktop_config.json
```

You can also edit it directly:

```bash
code ~/Library/Application\ Support/Claude/claude_desktop_config.json
```

---

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                      ARCHITECTURE                           │
└─────────────────────────────────────────────────────────────┘

Claude Desktop
│
├── Reads config on startup
│
├── Spawns: /path/to/diwa-agent/diwa.sh start
│
├── Connects via MCP protocol (stdio)
│
└── Tools become available in conversations


diwa-agent (Phoenix/Elixir)
│
├── Exposes MCP tools via SSE endpoint
│
├── Manages contexts, memories, relationships
│
└── Persists to PostgreSQL
```

---

## Updating

To update diwa-agent:

```bash
cd /path/to/diwa-agent
git pull
mix deps.get
mix ecto.migrate
```

Then restart Claude Desktop.

---

## Uninstalling

1. Remove the entry from Claude Desktop config
2. Restart Claude Desktop
3. Optionally delete the repo and database:

```bash
dropdb diwa_agent_dev
rm -rf /path/to/diwa-agent
```

---

## Getting Help

- **Documentation:** [docs.diwa.ph](https://docs.diwa.ph)
- **Issues:** [github.com/diwahq/diwa-agent/issues](https://github.com/diwahq/diwa-agent/issues)
- **Discussions:** [github.com/diwahq/diwa-agent/discussions](https://github.com/diwahq/diwa-agent/discussions)

---

## License

diwa-agent is open source under the [Apache 2.0 License](LICENSE).

---

*Happy building! 🚀*

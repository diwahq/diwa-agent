# 🧠 Diwa Agent - AI Memory That Actually Works

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Elixir](https://img.shields.io/badge/Elixir-1.16+-purple.svg)](https://elixir-lang.org/)
[![MCP](https://img.shields.io/badge/MCP-Compatible-green.svg)](https://modelcontextprotocol.io/)

**Stop losing context every time your AI assistant resets.** Diwa Agent is a local-first memory layer that remembers your decisions, requirements, and technical facts across sessions—no cloud required.

Built on the **Model Context Protocol (MCP)**, Diwa Agent works seamlessly with Claude Desktop, Cursor, Windsurf, and any MCP-compatible AI coding assistant.

---

## ⚡ 5-Minute Quick Start

### 1. Install (2 minutes)

**Prerequisites**: Elixir 1.16+ and Erlang/OTP 26+

```bash
git clone https://github.com/diwahq/diwa-agent.git
cd diwa-agent

# Install dependencies and set up database
mix deps.get
mix ecto.setup
```

### 2. Connect to Claude Desktop (2 minutes)

Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "diwa": {
      "command": "mix",
      "args": ["run", "--no-halt"],
      "cwd": "/absolute/path/to/diwa-agent"
    }
  }
}
```

**Replace `/absolute/path/to/diwa-agent`** with your actual path, then **restart Claude Desktop**.

### 3. Start Using It (1 minute)

In Claude Desktop, try these commands:

```
@start                    # Auto-detects your project or lets you choose
@note "API uses REST"     # Store a quick fact
@decide "Use PostgreSQL for production" because "Better JSONB support"
@search "API"             # Find what you stored
```

That's it! Diwa is now tracking your project knowledge.

---

## 🎯 Why Diwa Agent?

### The Problem
- AI assistants forget everything when you start a new chat
- You re-explain the same architecture decisions daily
- Important requirements get lost between sessions
- No way to track what you've already decided

### The Solution
Diwa Agent gives your AI assistant a **persistent memory**:

✅ **Remembers Forever**: Decisions, requirements, and facts survive session resets  
✅ **Context-Aware**: Auto-detects which project you're working on via git  
✅ **Zero Cloud**: Everything stays on your machine (SQLite database)  
✅ **MCP Standard**: Works with any MCP-compatible AI tool  
✅ **Lightweight**: No Docker, no server setup, just Elixir

---

## 🏗️ Architecture

Diwa Agent is the **Community Edition** of the Diwa ecosystem:

| Feature | Community (Agent) | Enterprise (Cloud) |
|---------|-------------------|-------------------|
| **Database** | SQLite | PostgreSQL |
| **Deployment** | Local only | Team-shared |
| **Search** | Text search (ILIKE) | Vector search (pgvector) |
| **Auto-Context** | ✅ UGAT detection | ✅ UGAT + ACE Engine |
| **Conflict Detection** | ❌ | ✅ Patent #3 |
| **Health Scoring** | ❌ | ✅ Patent #1 |
| **License** | Apache 2.0 | BSL 1.1 |

**For teams and advanced features**: See [Diwa Cloud](../diwa-cloud/README.md)

---

## 📚 Core Concepts

### Contexts
Think of a Context as a **project workspace**. Each git repo typically maps to one Context. Diwa auto-detects contexts using:
- Git remote URL
- Working directory path
- Manual binding

### Memories
Everything you store—notes, decisions, requirements—is a Memory. They're automatically:
- Timestamped
- Searchable
- Versioned
- Tagged

### Shortcuts
Use `@` commands for common operations:

| Shortcut | Does |
|----------|------|
| `@start` | Begin session, see handoff from last time |
| `@note "text"` | Quick memory |
| `@decide "choice" because "reason"` | Record decision |
| `@search "keyword"` | Find memories |
| `@status` | Project health check |
| `@end` | Close session with handoff note |

---

## 🔧 MCP Tools Reference

Diwa provides 40+ MCP tools. Here are the essentials:

### Session Management
- `start_session`: Initialize with auto-context detection
- `end_session`: Generate handoff note for next session
- `get_active_handoff`: Resume where you left off

### Memory Operations  
- `add_memory`: Store any knowledge
- `search_memories`: Find by keyword
- `update_memory`: Edit existing memory
- `delete_memory`: Remove outdated info

### Decision Tracking
- `record_decision`: Architecture choices with rationale
- `record_lesson`: Capture what you learned
- `flag_blocker`: Mark technical obstacles

### Context Management
- `create_context`: New project workspace
- `list_contexts`: See all your projects
- `detect_context`: Auto-find from git/path

**Full tool list**: Run `list_tools` in your MCP client or see [docs/TOOLS.md](./docs/TOOLS.md)

---

## 🚀 Advanced Setup

### For Cursor

Add to `.cursor/mcp_config.json`:

```json
{
  "mcpServers": {
    "diwa": {
      "command": "mix",
      "args": ["run", "--no-halt"],
      "cwd": "/path/to/diwa-agent"
    }
  }
}
```

### For Windsurf

Add to your Windsurf MCP configuration (location varies by OS).

### For Other MCP Clients

Diwa Agent implements the standard MCP stdio transport. Configure your client to run:  
**Command**: `mix run --no-halt`  
**CWD**: `/path/to/diwa-agent`

---

## 📖 Documentation

- **[Getting Started](../docs/getting-started.md)**: Detailed setup and first steps
- **[MCP Setup Guide](../docs/mcp-setup.md)**: Client-specific configuration
- **[Migration Guide](../docs/MIGRATION_GUIDE.md)**: Upgrade to Diwa Cloud
- **[Architecture](../docs/ARCHITECTURE.md)**: How Agent and Cloud relate
- **[Data Format](../docs/DATA_FORMAT.md)**: Export/import specification

---

## ⤴️ Migrating to Enterprise

When you're ready for team features, advanced analytics, or vector search:

```bash
# Export your local knowledge
mix diwa.export --output my_project.json

# Set up Diwa Cloud (see Cloud README)
cd ../diwa-cloud
mix diwa.import my_project.json
```

**Zero data loss.** UUIDs and timestamps are preserved for perfect continuity.

See the [Migration Guide](../docs/MIGRATION_GUIDE.md) for details.

---

## 🛠️ Development

### Requirements
- **Elixir**: 1.16 or higher
- **Erlang/OTP**: 26 or higher
- **SQLite3**: Usually pre-installed on macOS/Linux

### Running Tests

```bash
mix test
```

### Project Structure

```
diwa-agent/
├── lib/
│   └── diwa_agent/
│       ├── storage/          # SQLite persistence
│       ├── tools/            # MCP tool implementations
│       ├── shortcuts/        # @ command registry
│       └── workflow/         # Session management
├── priv/repo/migrations/     # Database schema
└── test/                     # Test suite
```

---

## 🤝 Contributing

Diwa Agent is open source (Apache 2.0). Contributions welcome!

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

**Apache License 2.0** - Free for commercial and personal use.

See [LICENSE](LICENSE) for full terms.

---

## 🔗 Links

- **Website**: [diwa.one](https://diwa.one)
- **Documentation**: [docs/](../docs/)
- **Enterprise Edition**: [diwa-cloud](../diwa-cloud/)
- **MCP Specification**: [modelcontextprotocol.io](https://modelcontextprotocol.io/)

---

**Built with ❤️ for developers who are tired of explaining the same thing twice.**

Questions? Open an issue or join the discussion.

# Diwa Agent - The Open Source Context & Memory Layer

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Diwa Agent** is a professional-grade **Model Context Protocol (MCP)** server built in Elixir. It provides autonomous context management and persistent memory for AI coding assistants (like Claude, Cursor, and Windsurf).

> 🚀 **Note:** This is the open-source agent component of the Diwa Platform. For enterprise features (Health Scoring, Auto-Context Extraction, Conflict Arbitration), please visit [diwa.one](https://diwa.one).

## 🎯 What is Diwa Agent?

Diwa Agent acts as a "long-term memory" and "project manager" for your AI assistant. Instead of starting every chat session from scratch, Diwa allows your AI to:
- **Remember** decisions, requirements, and lessons across sessions.
- **Track** project status, tasks, and blockers.
- **Search** past conversations and architectural notes.
- **Organize** knowledge into structured contexts (Projects/Workspaces).

It adheres to the [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) standard, making it plug-and-play compatible with modern AI tools.

## ✨ Core Features (OSS)

- **🧠 Persistent Memory**: Store notes, decisions, and technical facts that survive chat session resets.
- **📂 Context Management**: Organize memories into distinct projects (Contexts).
- **🔍 Semantic Search**: Find relevant memories using vector embeddings (OpenAI) or keyword search (PostgreSQL).
- **📋 Project Tracking**: Manage requirements, tasks, and blockers explicitly.
- **🏎️ High Performance**: Built on Elixir/OTP and PostgreSQL for sub-millisecond response times.
- **🔌 Standard MCP**: Full support for MCP tools and resources.

## 🚀 Quick Start

### 1. Run with Docker (Recommended)

```bash
docker run -d \
  -p 4000:4000 \
  -e DATABASE_URL="postgresql://user:pass@host/db" \
  -e OPENAI_API_KEY="sk-..." \
  ghcr.io/diwahq/diwa-agent:latest
```

### 2. Configure Claude Desktop

Add this to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "diwa": {
      "command": "docker",
      "args": ["run", "-i", "--rm", "-e", "OPENAI_API_KEY=sk-...", "ghcr.io/diwahq/diwa-agent:latest"]
    }
  }
}
```

## 📚 Available Tools

The agent provides the following MCP tools to your AI assistant:

### Memory & Context
- `create_context(name, description)`
- `add_memory(context_id, content)`
- `search_memories(query)`
- `list_memories(context_id)`

### Project Management
- `set_project_status(status, completion_pct)`
- `add_requirement(title, description)`
- `flag_blocker(title, description)`
- `record_decision(decision, rationale)`

### Workflow
- `set_handoff_note(summary, next_steps)`
- `get_active_handoff(context_id)`

## 🛠️ Development

### Prerequisites
- Elixir 1.15+
- PostgreSQL 15+ (with `pgvector` extension)

### Setup

```bash
# Clone the repo
git clone https://github.com/diwahq/diwa-agent.git
cd diwa-agent

# Install dependencies
mix deps.get

# Setup Database
mix ecto.setup

# Run the server
mix run --no-halt
```

> ⚠️ **Architecture Note:** This project relies on the `diwa_schema` shared library for Ecto schemas and migrations. Ensure the sibling directory structure is maintained if running from source.

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Built with ❤️ by the Diwa Team**

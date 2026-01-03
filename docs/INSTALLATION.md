# 📦 Installation Guide

Diwa can be installed and run in multiple ways depending on your needs.

| Method | Best For | Pros | Cons |
|--------|----------|------|------|
| **Source Build** | Developers, Local Usage | Full control, standard `stdio` integration with Claude | Requires Elixir/Postgres installed locally |
| **Docker** | Deployment, Isolation | Easy setup, bundled services (Postgres + Vector) | Harder to hook into local Claude Desktop via `stdio` |

---

## Method 1: Source Build (Recommended for Claude Desktop)

This is the standard way to run Diwa locally as a Claude Desktop extension.

### Prerequisites
- Elixir 1.18+ (`brew install elixir`)
- PostgreSQL 14+ (`brew install postgresql`)
- `pgvector` extension (Optional, but recommended for Semantic Search)

### Steps

1. **Clone and Prepare:**
   ```bash
   git clone https://github.com/yourusername/diwa.git
   cd diwa
   mix deps.get
   mix compile
   ```

2. **Setup Database:**
   ```bash
   # Ensure Postgres is running
   mix ecto.setup
   ```

3. **Configure Claude Desktop:**
   Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:
   ```json
   {
     "mcpServers": {
       "diwa": {
         "command": "/absolute/path/to/diwa/diwa.sh",
         "args": ["start"],
         "env": {
           "OPENAI_API_KEY": "sk-..."
         }
       }
     }
   }
   ```
   *Note: Use the absolute path to your cloned directory.*

---

## Method 2: Docker / Container

See [docs/DOCKER.md](DOCKER.md) for detailed instructions on running Diwa as a containerized service.

This method is ideal if you want to run the **Dashboard** and **Context Lattice** on a server or completely isolated from your host system.

---

## Method 3: Escript (Legacy)

Diwa can be compiled into a single binary executable.

> ⚠️ **Warning:** Escripts have limited support for NIFs (Native Implemented Functions). Since Diwa uses `sqlite` (exqlite) or `pgvector`, you might encounter runtime errors depending on your OS architecture. We recommend Method 1 instead.

```bash
mix escript.build
./diwa start
```

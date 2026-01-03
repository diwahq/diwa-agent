# 🐳 Running Diwa with Docker

Diwa provides official Docker images for simplified deployment and isolation. The Docker setup includes a pre-configured database with `pgvector` support, making it the easiest way to get the full "Enterprise" experience including Semantic Search.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (usually included with Docker Desktop)

## 🚀 Quick Start (Docker Compose)

The repository includes a `docker-compose.yml` that orchestrates Diwa and a PostgreSQL database.

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/diwa.git
   cd diwa
   ```

2. **Configure Environment:**
   Create a `.env` file (optional if you just want to set the API key inline):
   ```bash
   export OPENAI_API_KEY=sk-your-key-here
   ```

3. **Start the Stack:**
   ```bash
   docker compose up -d
   ```
   This will:
   - Start a PostgreSQL 16 database with `pgvector` enabled (port 5440 mapped to host).
   - Build and start the Diwa container (port 4000).

4. **Verify Installation:**
   - **Dashboard:** Open `http://localhost:4000/dashboard`
   - **Logs:** Run `docker compose logs -f diwa`

5. **Stop:**
   ```bash
   docker compose down
   ```
   *Note: Data is persisted in the `postgres_data` volume.*

## 🔌 Claude Desktop Integration (Docker)

To use Diwa running in Docker with Claude Desktop, we need to bridge the stdio or use a remote generic client. **However, currently, the Docker container runs as a long-running service (HTTP server).**

For **local** usage with Claude Desktop via stdio, we recommend the **Source Build** method (see [INSTALLATION.md](INSTALLATION.md)).

*If you specifically want to run the MCP server inside Docker and have Claude talk to it:*
You can use `docker exec` to tunnel to the running container or run a one-off command, but maintaining the interactive `stdio` session can be tricky.

**Recommended Pattern for Docker Users:**
Use Docker for the **Server/Dashboard/Database** (the "Backbone"), and connect Claude to it.
*(Note: Diwa currently runs the MCP server as part of the main application. Future versions will support MCP-over-SSE/HTTP natively for remote connections.)*

## 🛠 Manual Build

To build the image manually without Compose:

```bash
docker build -t diwa:latest .
```

To run it (requires an external Postgres database):

```bash
docker run -p 4000:4000 \
  -e DATABASE_URL="ecto://user:pass@host/db" \
  -e OPENAI_API_KEY="sk-..." \
  diwa:latest
```

## ⚙️ Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | Postgres connection string | required |
| `OPENAI_API_KEY` | Key for Semantic Search embeddings | optional |
| `POOL_SIZE` | Database connection pool size | `10` |
| `PORT` | HTTP port for Dashboard/Health | `4000` |
| `DIWA_DISABLE_WEB` | Set "true" to disable web dashboard | `false` |

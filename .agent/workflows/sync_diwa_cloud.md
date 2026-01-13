---
description: Strategy for syncing Diwa Agent (Core) features to Diwa Cloud (Enterprise) without manual copying.
---

# Sync Strategy: Path Dependency & Shared Core

To avoid manual copying of files between `diwa-agent` and `diwa-cloud`, we treat `diwa-agent` as the **Upstream Core Library**.

## 1. Establish Path Dependency

In your `diwa-cloud` repository's `mix.exs`, add `diwa-agent` as a local dependency. This allows `diwa-cloud` to compile and use the exact source code of `diwa-agent` in real-time.

```elixir
# diwa-cloud/mix.exs
def deps do
  [
    {:diwa_agent, path: "../diwa-agent", override: true},
    # ... other deps
  ]
end
```

## 2. Shared Configuration (The "Repo" Link)

Since `diwa-agent` uses `DiwaAgent.Repo` internally (hardcoded aliases), `diwa-cloud` must configure this Repo to point to the Enterprise Database (Postgres).

In `diwa-cloud/config/config.exs`:

```elixir
# Configure DiwaAgent.Repo to use Postgres instead of SQLite
config :diwa_agent, DiwaAgent.Repo,
  adapter: Ecto.Adapters.Postgres,
  url: System.get_env("DATABASE_URL"),
  pool_size: 10

# Disable DiwaAgent's auto-migration or startup tasks if needed
config :diwa_agent, :auto_migrate, false
```

## 3. Merging Tool Definitions

To expose `diwa-agent` tools (like `@start`, `@help`, `@bug`) in `diwa-cloud` without rewriting them:

In `diwa-cloud/lib/diwa_cloud/tools/definitions.ex`:

```elixir
def all_tools do
  local_tools = [
     # ... enterprise specific tools
  ]
  
  # Merge in Core tools
  local_tools ++ DiwaAgent.Tools.Definitions.all_tools()
end
```

In `diwa-cloud/lib/diwa_cloud/tools/executor.ex`:

```elixir
def execute(tool_name, args) do
  # Try local tools first, then fallback to core
  case run_local_tool(tool_name, args) do
    {:handled, response} -> response
    :unhandled -> DiwaAgent.Tools.Executor.execute(tool_name, args)
  end
end
```

## 4. Unified Context (UGAT)

To manage context across both repositories during development:

1.  **Run `diwa-agent` Local Server** (acts as the bridge).
2.  **Bind Contexts**:
    *   Create Context "Agent Core" -> Linked to `/codes/diwa-agent`.
    *   Create Context "Cloud Ent" -> Linked to `/codes/diwa-cloud`.
3.  **Link Them**:
    *   `@link_contexts Agent Core <-> Cloud Ent`
4.  **Result**:
    *   When working in `diwa-cloud`, the Agent (Claude) can traverse the graph to `diwa-agent` to understand the core logic it relies on.

## Summary

*   **Zero Copy**: Code lives in `diwa-agent`. `diwa-cloud` imports it.
*   **One Source of Truth**: Fix a bug in Agent -> Fixed in Cloud immediately.
*   **Enterprise Extensibility**: `diwa-cloud` wraps and extends the Core.

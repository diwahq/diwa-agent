# Migration Safety System

## TL;DR

**Do NOT run migrations from the `diwa-agent` repository.** All database schema management is performed from the `diwa-cloud` (Enterprise) repository.

```bash
# ❌ Wrong (blocked)
cd diwa-agent && mix ecto.migrate

# ✅ Correct
cd diwa-cloud && mix ecto.migrate
```

---

## Why This Exists

`diwa-agent` (Core) and `diwa-cloud` (Enterprise) share the same PostgreSQL database schema. To avoid duplicate migrations, conflicting timestamps, and schema drift, we have established `diwa-cloud` as the **Single Source of Truth** for the database schema.

Running migrations from both repositories would lead to:
- Conflicting migration files
- Inconsistent database states across development and production
- Hard-to-debug deployment failures

---

## The 3-Layer Protection System

We have implemented a proactive safety system to prevent accidental migrations in the core repository.

### Layer 1: mix.exs Guardrails (Hard Block)

Destructive Ecto commands are aliased in `mix.exs` to run a safety check before proceeding. If you attempt to run `mix ecto.migrate`, `rollback`, or `drop`, the system will intercept the command and exit with an error.

**How it works:**
The `mix.exs` aliases use a `check_migration_allowed/1` function:
```elixir
"ecto.migrate": [&check_migration_allowed/1, "ecto.migrate"]
```

### Layer 2: Bypass Switch (Expert Mode)

While migrations are blocked by default, we provide a bypass for core-only local development or emergency fixes.

To allow migrations in the current shell session, set the following environment variable:
```bash
export ALLOW_CORE_MIGRATION=true
# Or run 
ALLOW_CORE_MIGRATION=true mix ecto.migrate
```

### Layer 3: CI/CD Enforcement

Our GitHub Actions pipelines for `diwa-agent` are configured to fail if any new files are added to `priv/repo/migrations/` unless they have been explicitly reviewed and ported from `diwa-cloud`.

---

## Troubleshooting

### Error: "[SAFETY BLOCK] Database migrations in 'diwa-agent' are restricted"

This is working as intended. Please switch to your local `diwa-cloud` directory to manage the schema:

```bash
cd ../diwa-cloud
mix ecto.migrate
```

### Schema Out of Sync in diwa-agent

If you see errors in `diwa-agent` such as `column "xyz" does not exist`, it means your local database is behind the latest version in `diwa-cloud`. 

**Solution:**
1. Navigate to `diwa-cloud`.
2. Run `mix ecto.migrate`.
3. Restart the `diwa-agent` server.

---

## Roadmap: Shared Schema Library

In the future, we plan to extract the database schemas and migrations into a dedicated hexagonal package (`diwa_schema`) that both repositories will depend on. 

```text
diwa_schema (Hex Package)
├── lib/diwa_schema/      # Shared Ecto Schemas
└── priv/repo/migrations/ # Unified Migrations
```

Once this is implemented, the repository-level blocks will be removed in favor of a unified library-managed migration path.

---

## Related Decisions
- **Decision: Dual Repository Architecture** (Memory ID: `601d57b6-c47d-42b1-b733-4d240f6e7353`)
- **Spec: Migration Safety Guardrail** (Memory ID: `9d97d911-dd7b-43cb-b426-cccbfd4b90dd`)

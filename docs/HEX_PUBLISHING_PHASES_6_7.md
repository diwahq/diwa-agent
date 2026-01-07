# Hex Publishing Workflow: Phases 6-7 Specification

## Overview

This document specifies the remaining phases of the Hex Publishing Workflow for the `diwa_schema` package.

**Status**: Phases 1-5 complete ✅  
**Package**: https://hex.pm/packages/diwa_schema/0.1.0  
**Remaining**: Phases 6-7 (Optional)

---

## Phase 6: Update CI Workflows

### Objective
Update GitHub Actions CI workflows in all 3 repositories to work with the published Hex package instead of local path dependencies.

### Repositories to Update
1. `diwahq/diwa_schema`
2. `diwahq/diwa-agent`
3. `diwahq/diwa-cloud`

### Tasks

#### 6.1 diwa_schema CI Workflow

**File**: `.github/workflows/ci.yml`

**Requirements**:
- Run on push to `main` and pull requests
- Test matrix: Elixir 1.15, 1.16, 1.17 / OTP 25, 26, 27
- Steps:
  - Checkout code
  - Setup Elixir/OTP
  - Install dependencies: `mix deps.get`
  - Check formatting: `mix format --check-formatted`
  - Compile with warnings as errors: `mix compile --warnings-as-errors`
  - Run tests: `mix test`
  - Generate documentation: `mix docs` (verify no errors)

**New File**: `.github/workflows/release.yml`

**Requirements**:
- Trigger on tag push (pattern: `v*`)
- Automatically publish to Hex.pm on new version tags
- Steps:
  - Checkout code
  - Setup Elixir
  - Install dependencies
  - Run tests
  - Build Hex package: `mix hex.build`
  - Publish to Hex: `mix hex.publish --yes` (requires `HEX_API_KEY` secret)

#### 6.2 diwa-agent CI Workflow

**File**: `.github/workflows/ci.yml` (if exists)

**Changes Required**:
- Remove any local path setup for `diwa_schema`
- Ensure `mix deps.get` fetches from Hex.pm
- Verify migration path works: `deps/diwa_schema/priv/repo/migrations`
- Test ecto commands:
  ```yaml
  - name: Run migrations
    run: mix ecto.migrate
  ```

#### 6.3 diwa-cloud CI Workflow

**File**: `.github/workflows/ci.yml` (if exists)

**Changes Required**:
- Same as diwa-agent (remove local path assumptions)
- Ensure PostgreSQL service is available for tests
- Verify migrations run correctly with Hex package

### Secrets to Configure

**For diwa_schema repo**:
- `HEX_API_KEY`: Your Hex.pm API key for automated publishing

**To generate**:
```bash
mix hex.user auth
mix hex.user key generate ci --permissions api:write,docs:write
```

### Estimated Time
- **2-3 hours** (includes testing and debugging)

---

## Phase 7: Deploy to Staging and Verify

### Objective
Deploy both `diwa-agent` and `diwa-cloud` to a staging environment and verify that:
1. Hex package dependency resolves correctly
2. Migrations run successfully
3. All features work as expected

### Prerequisites
- Staging environment available
- Database access configured
- Deployment pipeline ready

### Tasks

#### 7.1 Deploy diwa-agent to Staging

**Steps**:
1. Build release with Hex dependency:
   ```bash
   MIX_ENV=prod mix release
   ```

2. Deploy to staging environment

3. Verify migrations:
   ```bash
   # SSH to staging
   ./bin/diwa_agent eval "DiwaAgent.Release.migrate()"
   ```

4. Verify package version:
   ```bash
   ./bin/diwa_agent eval "Application.spec(:diwa_schema, :vsn)"
   # Should output: '0.1.0'
   ```

5. Run smoke tests:
   - MCP server starts correctly
   - Can create contexts
   - Can add memories
   - Migrations are at correct version

#### 7.2 Deploy diwa-cloud to Staging

**Steps**:
1. Build release:
   ```bash
   MIX_ENV=prod mix release
   ```

2. Deploy to staging

3. Verify migrations:
   ```bash
   ./bin/diwa eval "Diwa.Release.migrate()"
   ```

4. Verify package version:
   ```bash
   ./bin/diwa eval "Application.spec(:diwa_schema, :vsn)"
   ```

5. Run smoke tests:
   - API endpoints respond
   - Database queries work
   - All enterprise features function
   - Consensus mechanisms work

#### 7.3 Integration Testing

**Tests to Run**:
1. **Schema Consistency**: Verify both apps use identical schema version
2. **Migration Idempotency**: Run `mix ecto.migrate` multiple times (should be idempotent)
3. **Cross-App Data**: Create data in one app, verify accessible in other
4. **Rollback Test**: Test `mix ecto.rollback` works correctly
5. **Performance**: Verify no performance regression

### Rollback Plan

If issues are found:

1. **Quick Rollback**:
   ```elixir
   # In mix.exs, temporarily revert to local path
   {:diwa_schema, path: "../diwa_schema"}
   ```

2. **Fix Forward**:
   - Publish patched version (e.g., v0.1.1) to Hex
   - Update dependencies to `~> 0.1.1`
   - Redeploy

### Verification Checklist

- [ ] diwa-agent builds with Hex package
- [ ] diwa-cloud builds with Hex package
- [ ] Migrations run in both apps
- [ ] Both apps show correct schema version (0.1.0)
- [ ] MCP protocol works (diwa-agent)
- [ ] API endpoints work (diwa-cloud)
- [ ] Database queries execute correctly
- [ ] No errors in logs
- [ ] Performance is acceptable

### Estimated Time
- **1-2 hours** (includes deployment and testing)

---

## Success Criteria

**Phase 6 Complete When**:
- ✅ All 3 repos have working CI workflows
- ✅ Tests pass on all matrix configurations
- ✅ Hex publishing workflow is automated for diwa_schema

**Phase 7 Complete When**:
- ✅ Both apps deployed to staging
- ✅ All smoke tests pass
- ✅ Integration tests pass
- ✅ No regressions identified
- ✅ Team approves for production

---

## Notes

### Why These Phases Are Optional

1. **CI Workflows**: Current setup works; CI can be added incrementally
2. **Staging Deploy**: Production deployment can proceed directly if confident
3. **Risk is Low**: Schema library is well-tested; Hex publishing is straightforward

### When to Execute

- **Phase 6**: Before merge to main (if enforcing CI checks)
- **Phase 7**: Before production deployment (if staging env exists)

### Alternative Approach

**Skip to Production**:
- If no staging environment exists
- If CI isn't enforced yet
- Risk mitigation: Monitor closely, have rollback ready

---

## References

- GitHub Actions Docs: https://docs.github.com/en/actions
- Hex Publishing Docs: https://hex.pm/docs/publish
- Mix Release Docs: https://hexdocs.pm/mix/Mix.Tasks.Release.html
- Ecto Migrations: https://hexdocs.pm/ecto_sql/Ecto.Migrator.html

---

**Document Version**: 1.0  
**Created**: 2026-01-07  
**Status**: Ready for execution

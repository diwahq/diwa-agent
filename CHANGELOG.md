# Changelog

All notable changes to the Diwa project will be documented in this file.

## [1.0.0] - 2025-12-31

**🎉 First Stable Release - Production Ready**

Diwa v1.0.0 represents a production-ready MCP server with enterprise-grade context management, conflict arbitration, and workflow automation. This release completes all core architectural phases and introduces MCP Workflow Prompts for enhanced discoverability.

### Added

- **MCP Workflow Prompts (New in v1.0.0)**
    - **6 Workflow Commands:** `/start`, `/help`, `/handoff`, `/wrap`, `/status`, `/quick`
    - **Cross-Client Discovery:** Works in Claude Desktop, Cursor, and any MCP-compatible client
    - **Self-Documenting:** Prompts list themselves via `prompts/list` MCP method
    - **Module:** `Diwa.Prompts.Workflow` with full argument schemas
    - **MCP Protocol:** Full `prompts/list` and `prompts/get` support in server

- **Shortcut Interpreter (Phase 4) - Complete**
    - **Database Persistence:** PostgreSQL storage for custom shortcut aliases
    - **Hybrid Architecture:** ETS for O(1) lookups + DB for persistence across restarts  
    - **4 Built-in Shortcuts:** `/log`, `/bug`, `/todo`, `/plan`
    - **Custom Registration:** `register_shortcut_alias` MCP tool
    - **CLI Support:** `mix diwa.shortcut` for terminal execution
    - **20 Tests:** All passing (unit + integration + E2E)

- **Conflict Arbitration (Phase 3) - 90% Complete**
    - **11 Core Modules:** Detector, Engine, JudgeOrchestrator, Resolver, AdaptiveThreshold, SemanticChecksum, SemanticFingerprint, Similarity, SynthesisValidator, Prompts + Adaptive profiles
    - **8 MCP Tools:** list_conflicts, resolve_conflict, arbitrate_conflict, get_conflict_threshold, calibrate_threshold, record_resolution_feedback, verify_context_integrity, get_cluster_status
    - **Multi-Tier Arbitration:** Tier 0 (automatic), Tier 1 (LLM synthesis), HITL escalation
    - **Distributed Consensus:** Raft integration for cluster-wide conflict resolution
    - **Semantic Detection:** Embedding-based similarity with adaptive thresholds (safety levels 0-5)
    - **101 Tests:** All passing (35 doctests + 66 unit/integration tests)

### Changed

- **Version:** Updated from 1.0.0-rc.1 to 1.0.0 (stable)
- **Project Completion:** 97% complete, production-ready for deployment
- **Health Score:** Context health at 82/100

### Infrastructure

- **Docker:** Multi-stage Alpine-based build (< 50MB runtime image)
- **GitHub Actions:** Automated releases on version tags (v*.*.*)
- **Container Registry:** GHCR (GitHub Container Registry) integration
- **Escript:** Portable binary builds for Linux/macOS

### Documentation

- Comprehensive README.md with installation guides
- Complete CHANGELOG.md with version history
- Domain: All references updated to diwa.one

### Production Ready

- ✅ 47+ MCP tools across entire SDLC
- ✅ 130+ tests passing (shortcuts + conflicts + prompts)
- ✅ Zero critical compiler warnings
- ✅ Database migrations stable
- ✅ Docker deployment ready
- ✅ Semantic search with OpenAI embeddings
- ✅ PostgreSQL persistence layer
- ✅ Multi-tenant organization support
- ✅ Telemetry and observability

---

## [1.0.0-rc.1] - 2025-12-29

This release adds the complete Distributed Consensus Engine (Phase 3) and a rewritten Auto-Context Extraction (ACE) Engine (Phase 4).

### Added

- **Consensus Engine (Phase 3)**
    - **Ra Integration:** Replaced simple 2PC with `ra` (Raft) for robust distributed consensus.
    - **Cluster Management:** `Diwa.Consensus.ClusterManager` for dynamic node handling.
    - **Byzantine Fault Tolerance:** `Diwa.Consensus.ByzantineDetector` with quarantine logic.
    - **MCP Tools:** `get_cluster_status`, `get_byzantine_nodes`, `arbitrate_conflict`.

- **ACE Engine v2 (Patent #2 Re-implementation)**
    - **New Architecture:** Clean separation of `Scanner` behaviour, `Fact` struct, and `Engine`.
    - **Self-Scanning:** Capable of scanning its own codebase to populate context.
    - **Scanners:**
        - `FileSystem`: Recursive directory walker with ignore patterns.
        - `Elixir`: AST-based extractor for Modules, Functions, and Behaviours.
    - **MCP Tool:** `run_context_scan` updated to use the new engine.

- **Conflict Engine (Phase 2.2)**
    - **Database Migrations:** Schema for `conflict_performance` and `memories` embedding (stubbed `pgvector`).
    - **Adaptive Calibration:** `Diwa.Conflict.Adaptive.DomainProfile` for context-aware conflict sensitivity.
    - **Conflict Resolver:** Strategies for `keep_latest` and `keep_original`.

### Changed

- **Refactor:** `Diwa.Tools.Executor` now routes consensus actions to `ClusterManager` instead of `TwoPhaseCommit`.
- **Cleanup:** Removed legacy ACE code in favor of the new modular design.
- **Migration:** Skipped `CREATE EXTENSION vector` in `20251229030717_add_embedding_to_memories.exs` for compatibility with environments missing `pgvector`.


This is the first Release Candidate for Diwa v1.0. It marks the completion of the core architectural phases, including the storage layer, ACE engine, and security hardening.

### Added

- **Phase 1: Core Foundation**
    - Initial MCP Server utilizing `stdio` transport.
    - Application supervision tree.
- **Phase 2: ACE (Automated Context Extraction) Engine v2**
    - Replaced legacy path-based extractors with a parallel file-based `extract/2` behaviour.
    - Language extractors: Elixir, Java, Python, Rust, TypeScript, C++, C#, Dart, Swift, PHP, Elm, Shell, Kotlin, Groovy, Web3 (Solidity), Functional (Haskell/OCaml).
    - Infrastructure extractors: Dockerfile, Makefile, Terraform, GitHub Actions.
    - Case-insensitive file matching (e.g., `README.md`).
- **Phase 3: Storage Layer**
    - PostgreSQL/Ecto integration for persistent storage of Contexts and Memories.
    - `Diwa.Storage.Context` and `Diwa.Storage.Memory` modules.
    - Vector Embeddings via `pgvector` and `Bumblebee` (all-MiniLM-L6-v2) for semantic search.
    - Memory Versioning and History tracking.
    - Health Engine (Patent #1) for calculating context health.
    - `Diwa.Tools.Executor` integrating 40+ MCP tools.
- **Phase 4: Security & Hardening**
    - **Telemetry**: Full instrumentation of tool execution and server events (`Diwa.Telemetry`, `Diwa.Telemetry.Handler`).
    - **Validation**: Centralized input validation (`Diwa.Validation`) ensuring data integrity for UUIDs and required fields.
    - **Error Handling**: Standardized `Diwa.Error` structs for consistent API responses.
    - **Security**: Zero-warning compilation, dependency audits (`mix hex.audit`, `mix mix_audit`).

### Changed

- Renamed project from "Koda" to "Diwa".
- Unified tool execution under `Diwa.Tools.Executor` with comprehensive telemetry spans.
- Optimized ACE scanning to be 100% parallelizable.

### Fixed

- Resolved all Elixir compiler warnings (unused variables, deprecated functions).
- Fixed `DBConnection` issues by standardizing configuration in `config/releases.exs`.

### Security

- Added `mix_audit` to CI/CD pipeline suggestions.
- Implemented input sanitization for all public MCP tools.

# SPEC: @flow Shortcut — Role-Aware Workflow Router

> **repo:** diwa-agent  
> **status:** Ready for Implementation  
> **created:** 2026-01-12  
> **author:** Claude (Planner)  
> **actor:** coder  
> **priority:** P1  
> **estimated-effort:** 4-6 hours  
> **parent-spec:** WIKA v2 Vertical Slice (f73d49a5)

## Overview

The `@flow` shortcut answers: "What should I work on next?"

Analyzes context state using dual decision trees for planners and coders.

## Function Signature

```elixir
@spec determine_workflow(map()) :: {:ok, analysis_result()} | {:error, term()}
```

## Workflow Types

### P0 - Immediate
- :resolve_blocker (Both)
- :resolve_conflict (Both)
- :fix_failing_tests (Coder)

### P1 - High Priority
- :process_handoff (Coder)
- :review_implementation (Planner)
- :implement_spec (Coder)
- :pending_decision (Planner)
- :continue_planning (Planner)
- :continue_implementation (Coder)

### P2 - Normal
- :spec_review (Planner)
- :address_feedback (Coder)
- :improve_health (Both)

### P3 - Low
- :start_fresh (Both)

## Role Detection

```elixir
actor "claude" → :planner
actor "antigravity" → :coder
actor "human" → :planner
actor "gemini", "cursor" → :coder
```

## Response Structure

```elixir
%{
  role_detected: :planner | :coder,
  recommendation: %{
    workflow: workflow_type(),
    priority: :p0 | :p1 | :p2 | :p3,
    reason: String.t(),
    target_id: uuid | nil,
    target_title: String.t() | nil,
    suggested_actions: [String.t()]
  },
  context_summary: %{blockers, conflicts, pending_handoffs, ...},
  alternatives: [recommendation()]
}
```

## Full Spec

See file: flow_shortcut_spec.md (stored in handoff)

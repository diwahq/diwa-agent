---
description: Handoff Procedure
---

1. [MANDATORY] Use the `set_handoff_note` MCP tool to save the handoff to the persistent memory layer.
   - Do NOT write to `.agent/handoff.md` directly.
   - Requirement: `context_id` must be valid.

2. Generate a summary of the session:
   - Accomplishments
   - Next Steps
   - Active Files

3. Call `set_handoff_note(context_id, summary, next_steps, active_files)`

4. [OPTIONAL] Update `.agent/current-status.md` if significant milestones were reached.

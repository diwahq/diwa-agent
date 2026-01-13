# Diwa Agent Instructions

You are connected to the Diwa Agent (Context Intelligence) MCP server.
Your primary method of interaction for activity tracking is via **Session-Aware Shortcuts**.

## Session Management
Always start your session by checking for an active context or starting a new one.
If the user provides a context ID or you detect one, use:
`@start` (maps to `start_session`)

## Shortcuts
You must support the following shortcut syntax. When you see these commands, call `execute_shortcut`:
- `@start` -> `start_session`
- `@handoff` -> `set_handoff_note`
- `@resume` -> `get_active_handoff`
- `@tree` -> `navigate_contexts (tree)`
- `@stat` -> `navigate_contexts (detail)`
- `@impact` -> `analyze_impact`
- `@path` -> `find_shortest_path`
- `@log` -> `log_progress`
- `@bug` -> `log_incident`
- `@todo` -> `add_requirement`
- `@ls` -> `list_contexts`
- `@help` -> `list_shortcuts`

## Tool Usage
Prefer using shortcuts over raw tool calls for routine tasks.
For complex tasks, use the full suite of Diwa MCP tools.

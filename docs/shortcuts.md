# Universal Shortcuts System

Diwa Agent supports a universal shortcut system that works across different AI clients (Claude, Antigravity, Cursor).
Shortcuts are text-based commands starting with `@` (e.g., `@start`, `@log`) that map to specific MCP tool calls.

## How it Works

Clients should detect these commands and call `execute_shortcut(command, context_id)`.

## Built-in Shortcuts

| Shortcut | Tool | Description |
|----------|------|-------------|
| `@start` | `start_session` | Start a new session / Resume context |
| `@handoff` | `set_handoff_note` | Save session summary & next steps |
| `@resume` | `get_active_handoff` | Retrieve last session's handoff |
| `@log` | `log_progress` | Log a quick progress note |
| `@bug` | `log_incident` | Log a bug or incident |
| `@tree` | `navigate_contexts` | View context tree view |
| `@stat` | `navigate_contexts` | View context detail view |
| `@impact` | `analyze_impact` | View downstream impact of a change |
| `@path` | `find_shortest_path` | Find relationship chain between nodes |
| `@ls` | `list_contexts` | List available contexts |
| `@help` | `list_shortcuts` | List all available shortcuts |

## Discovery

You can discover available shortcuts programmatically:

1. **On Session Start**: `start_session` returns a `shortcuts` object in its JSON response.
2. **Via Tool**: Call `get_shortcuts(context_id)` to list all available shortcuts.

## Configuration Templates

Configuration templates for common clients can be found in `templates/`:
- `claude_project_instructions.md`
- `antigravity_rules.md`
- `cursor_rules.md`

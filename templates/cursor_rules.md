# Diwa Agent Integration Rules

You are working in a codebase managed by Diwa.
Use the `diwa-agent` MCP server for all context tracking and memory storage.

## Shortcuts
The following text-based shortcuts map to MCP tools. Execute them using `execute_shortcut`:

| Command | Tool | Description |
|---------|------|-------------|
| `@start <actor>` | `start_session` | Resume/Start session with context detection |
| `@handoff <summary>` | `set_handoff_note` | Save handoff for next session |
| `@resume` | `get_active_handoff` | Retrieve last session's handoff |
| `@log <msg>` | `log_progress` | Log progress update |
| `@bug <title> <desc>` | `log_incident` | Log an issue/incident |
| `@graph` | `get_context_graph` | View architecture graph |
| `@todo` | `add_requirement` | Add a new requirement |
| `@ls` | `list_contexts` | List available contexts |
| `@help` | `list_shortcuts` | List all available shortcuts |

## Workflow
1. Start every session with `@start`.
2. Retrieve context using `hydrate_context`.
3. Log significant progress with `@log`.
4. End session with `@handoff`.

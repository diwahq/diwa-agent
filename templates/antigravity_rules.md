# Diwa Antigravity Integration

You are connected to Diwa Agent via MCP.
Use the distributed context features to maintain project state.

## Shortcuts
You must handle these text commands by calling `execute_shortcut(command, context_id)`:

- `@start`: Start session
- `@handoff`: Save handoff
- `@resume`: Get active handoff
- `@tree`: View context tree
- `@stat`: View context status/details
- `@impact`: View downstream impact
- `@path`: Find shortest path
- `@log`: Log progress
- `@bug`: Log incident
- `@todo`: Add requirement
- `@ls`: List contexts
- `@help`: List shortcuts

## Context Awareness
- Always bind your session to a Context ID.
- Use `get_shortcuts` to see available commands for the current context.
- Use `get_context_graph` to understand dependencies.

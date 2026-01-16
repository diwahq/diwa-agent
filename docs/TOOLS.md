# 🔗 Complete MCP Tools Reference

This is the complete list of all tools available in Diwa Agent. Each tool is accessible through the Model Context Protocol.

---

## 📖 How to Read This Reference

Each tool entry shows:
- **Tool Name** - What to call it
- **Purpose** - What it does
- **Shortcut** - Quick `@` command (if available)
- **Parameters** - What information it needs
- **Example** - How to use it

**Note:** In MCP-compatible AI assistants, you often don't need to call tools directly. Just ask in natural language, and the AI will use the right tool!

---

## 🎯 Session Management

### `start_session`
**Purpose:** Begin a new work session  
**Shortcut:** `@start`

**Parameters:**
- `actor` (optional) - Who is starting (default: "user")
- `context_id` (optional) - Specific context to use
- `depth` (optional) - How much info to load: "minimal", "standard", "comprehensive"

**Example:**
```
@start
```

**What it does:**
- Auto-detects your project context
- Loads previous handoff note
- Shows pending tasks
- Lists available shortcuts

---

### `end_session`
**Purpose:** End your work session and create handoff note  
**Shortcut:** `@end "summary"`

**Parameters:**
- `session_id` (required) - Current session ID
- `summary` (required) - What you accomplished
- `next_steps` (optional) - What to do next

**Example:**
```
@end "Implemented user authentication, tested locally"
```

**What it does:**
- Creates handoff note with summary
- Includes queued items automatically
- Marks session as complete

---

### `get_active_handoff`
**Purpose:** See the last handoff note  
**Shortcut:** `@resume`

**Parameters:**
- `context_id` (required) - Which project

**Example:**
```
@resume
```

**What it returns:**
- Last session summary
- Next steps
- Active files
- Pending tasks

---

### `get_resume_context`
**Purpose:** Get comprehensive session resume info

**Parameters:**
- `context_id` (required)

**What it returns:**
- Handoff note
- Pending tasks
- Active blockers  
- Recent errors
- Health score

---

### `queue_handoff_item`
**Purpose:** Add item to handoff queue  
**Shortcut:** `@note "message"`

**Parameters:**
- `context_id` (required)
- `message` (required)
- `category` (optional) - "accomplishment", "next_step", "blocker", "decision"

**Example:**
```
@note "Finished login feature"
@note "this"  # Captures current context
```

---

### `list_handoff_queue`
**Purpose:** View queued handoff items  
**Shortcut:** `@queue` or `@notes`

**Parameters:**
- `context_id` (required)

**Example:**
```
@queue
```

**What it shows:**
- All items queued for next handoff
- In chronological order

---

## 💾 Memory Management

### `add_memory`
**Purpose:** Store any knowledge  
**Shortcut:** `@note "content"`

**Parameters:**
- `context_id` (required)
- `content` (required) - The information to store
- `tags` (optional) - Labels for organization
- `metadata` (optional) - Extra info (JSON)
- `actor` (optional) - Who added it
- `severity` (optional) - For incidents: "low", "moderate", "high", "critical"

**Example:**
```
@note "API endpoint is /api/v2/users"
```

---

### `add_memories`
**Purpose:** Store multiple memories at once

**Parameters:**
- `context_id` (required)
- `memories` (required) - Array of memory objects

**Example (via AI):**
```
"Store these facts: 1) Uses PostgreSQL 2) Deployed on AWS 3) Supports JSONB"
```

---

### `list_memories`
**Purpose:** See all memories in a context

**Parameters:**
- `context_id` (required)
- `limit` (optional) - Max number to return (default: 100)

**Example:**
```
"Show me all memories"
```

---

### `get_memory`
**Purpose:** Retrieve a specific memory by ID

**Parameters:**
- `memory_id` (required)

**Example:**
```
"Show me memory abc-123"
```

---

###`update_memory`
**Purpose:** Edit an existing memory  
**Shortcut:** `@revise <id> "new content"`

**Parameters:**
- `memory_id` (required)
- `content` (required) - New content

**Example:**
```
"Update memory xyz-789 to say 'Uses PostgreSQL 15'"
```

---

### `delete_memory`
**Purpose:** Remove a memory

**Parameters:**
- `memory_id` (required)

**Example:**
```
"Delete memory xyz-789"
```

**Note:** Soft delete - can be recovered from version history

---

### `search_memories`
**Purpose:** Find memories by keyword  
**Shortcut:** `@search "keyword"`

**Parameters:**
- `query` (required) - Search term
- `context_id` (optional) - Limit to specific context

**Example:**
```
@search "database"
@search "authentication"
```

---

### `link_memories`
**Purpose:** Create relationship between memories

**Parameters:**
- `parent_id` (required) - Parent memory
- `child_id` (required) - Child memory

**Example:**
```
"Link memory abc to memory xyz as parent-child"
```

---

### `get_memory_tree`
**Purpose:** View memory hierarchy starting from a root

**Parameters:**
- `root_id` (required) - Starting memory ID

**Example:**
```
"Show me the tree for memory abc-123"
```

---

## 🎯 Decision Tracking

### `record_decision`
**Purpose:** Document an important choice  
**Shortcut:** `@decide "choice" because "reason"`

**Parameters:**
- `context_id` (required)
- `decision` (required) - What you decided
- `rationale` (required) - Why you decided it
- `alternatives` (optional) - What else you considered
- `buffer` (optional) - Queue for batch commit

**Example:**
```
@decide "Use PostgreSQL" because "Need JSONB support and ACID compliance"
```

---

### `record_lesson`
**Purpose:** Capture what you learned  
**Shortcut:** `@lesson "title" "content"`

**Parameters:**
- `context_id` (required)
- `title` (required) - Lesson summary
- `content` (required) - Details
- `category` (optional) - e.g., "Architecture", "DevX", "Protocol"

**Example:**
```
"Record lesson: Never deploy on Fridays. Content: Production issues are harder to fix over weekend."
```

---

### `record_pattern`
**Purpose:** Document a reusable solution

**Parameters:**
- `context_id` (required)
- `name` (required) - Pattern name
- `description` (required) - What it does
- `example` (optional) - Code snippet

**Example:**
```
"Document pattern 'Repository Pattern' for database abstraction"
```

---

## 📋 Project Management

### `add_requirement`
**Purpose:** Track a must-have feature  
**Shortcut:** `@todo "title" "description"`

**Parameters:**
- `context_id` (required)
- `title` (required) - Short summary
- `description` (required) - Details
- `priority` (optional) - "High", "Medium", "Low"

**Example:**
```
@todo "Password reset" "Users must be able to reset forgotten passwords via email"
```

---

### `mark_requirement_complete`
**Purpose:** Mark requirement as done

**Parameters:**
- `requirement_id` (required)

**Example:**
```
"Mark requirement xyz as complete"
```

---

### `prioritize_requirement`
**Purpose:** Change requirement priority

**Parameters:**
- `requirement_id` (required)
- `priority` (required) - "High", "Medium", "Low"

**Example:**
```
"Set requirement xyz to high priority"
```

---

### `flag_blocker`
**Purpose:** Report something blocking progress  
**Shortcut:** `@flag "issue"`

**Parameters:**
- `context_id` (required)
- `title` (required) - What's blocking you
- `description` (required) - Details
- `severity` (optional) - "Critical", "Moderate"

**Example:**
```
@flag "Can't deploy - permissions error on production server"
```

---

### `resolve_blocker`
**Purpose:** Mark blocker as fixed

**Parameters:**
- `blocker_id` (required)
- `resolution` (required) - How it was fixed

**Example:**
```
"Resolve blocker xyz. Solution: Added SSH key to production server"
```

---

### `get_pending_tasks`
**Purpose:** See what's still to do

**Parameters:**
- `context_id` (required)
- `limit` (optional) - Max to return

**Example:**
```
"Show me pending tasks"
```

---

### `set_project_status`
**Purpose:** Update overall project status

**Parameters:**
- `context_id` (required)
- `status` (required) - e.g., "Planning", "Implementation", "Testing"
- `completion_pct` (required) - 0-100
- `notes` (optional)

**Example:**
```
"Set project status to Implementation, 60% complete"
```

---

### `get_project_status`
**Purpose:** View project overview  
**Shortcut:** `@status`

**Parameters:**
- `context_id` (required)

**Example:**
```
@status
```

**What it shows:**
- Current status and completion
- Memory count by type
- Recent activity
- Pending tasks

---

## 🗂️ Context Management

### `create_context`
**Purpose:** Create a new project workspace

**Parameters:**
- `name` (required) - Context name
- `description` (optional) - What the project is
- `organization_id` (optional) - If using organizations

**Example:**
```
"Create a new context called 'personal-blog'"
```

---

### `list_contexts`
**Purpose:** See all your projects  
**Shortcut:** `@list_contexts`

**Parameters:**
- `organization_id` (optional) - Filter by org
- `query` (optional) - Fuzzy search

**Example:**
```
"List all my contexts"
"Find contexts with 'blog' in the name"
```

---

### `get_context`
**Purpose:** Get details about a specific context  
**Shortcut:** `@info <context_id>`

**Parameters:**
- `context_id` (required)

**Example:**
```
@info abc-123
```

---

### `update_context`
**Purpose:** Edit context details

**Parameters:**
- `context_id` (required)
- `name` (optional) - New name
- `description` (optional) - New description

**Example:**
```
"Rename context abc-123 to 'marketing-website'"
```

---

### `delete_context`
**Purpose:** Remove a context (and all its memories!)

**Parameters:**
- `context_id` (required)

**Example:**
```
"Delete context abc-123"
```

**⚠️ Warning:** This cannot be undone!

---

## 🔍 Advanced Features

### `detect_context`
**Purpose:** Auto-find context from git/path

**Parameters:**
- `type` (required) - "git_remote" or "path"
- `value` (required) - Git URL or directory path

**Example (used automatically by `@start`):**
```
Detects: "You're in /projects/my-app with git remote github.com/me/my-app"
```

---

### `bind_context`
**Purpose:** Link context to git repo or path

**Parameters:**
- `context_id` (required)
- `type` (required) - "git_remote", "path", "env_var"
- `value` (required) - URL or path
- `metadata` (optional) - Extra info

**Example:**
```
"Bind this context to git remote github.com/me/my-app"
```

---

### `list_bindings`
**Purpose:** See all context bindings

**Parameters:**
- `context_id` (required)

**Example:**
```
"Show bindings for current context"
```

---

### `link_contexts`
**Purpose:** Create relationship between contexts

**Parameters:**
- `source_context_id` (required)
- `target_context_id` (required)
- `relationship_type` (required) - "depends_on", "relates_to", "child_of", "blocks"
- `metadata` (optional)

**Example:**
```
"Link frontend context to backend context as 'depends_on'"
```

---

### `get_context_graph`
**Purpose:** Visualize context relationships  
**Shortcut:** `@graph`

**Parameters:**
- `root_id` (required) - Starting context
- `depth` (optional) - How many levels (default: 3)
- `format` (optional) - "mermaid", "json", "list"

**Example:**
```
@graph
```

---

### `navigate_contexts`
**Purpose:** Browse contexts like a file system  
**Shortcuts:** `@ls`, `@cd`, `@tree`

**Parameters:**
- `context_id` (required) - Current context (like PWD)
- `target_path` (optional) - Where to go (".", "..", name, ID)
- `mode` (optional) - "list", "tree", "detail"

**Examples:**
```
@ls          # List related contexts
@cd ..       # Go to parent
@tree        # Show tree view
@stat        # Show details
```

---

## 🔄 Version Control

### `get_memory_history`
**Purpose:** See all versions of a memory

**Parameters:**
- `memory_id` (required)

**Example:**
```
"Show history for memory xyz"
```

---

### `rollback_memory`
**Purpose:** Revert to a previous version

**Parameters:**
- `memory_id` (required)
- `version_id` (required) - Which version to restore
- `reason` (required) - Why rolling back

**Example:**
```
"Rollback memory xyz to version v2 because incorrect info"
```

---

### `compare_memory_versions`
**Purpose:** See differences between versions  
**Shortcut:** `@diff <v1> <v2>`

**Parameters:**
- `version_id_1` (required)
- `version_id_2` (required)

**Example:**
```
@diff v1 v2
```

---

### `get_recent_changes`
**Purpose:** See what changed recently  
**Shortcut:** `@history`

**Parameters:**
- `context_id` (required)
- `limit` (optional) - How many to show (default: 20)

**Example:**
```
@history
```

---

## 🛠️ Workflow Tools

### `determine_workflow`
**Purpose:** Get AI suggestions for what to do next  
**Shortcut:** `@flow`

**Parameters:**
- `query` (optional) - Specific question
- `context_id` (optional) - Which project

**Example:**
```
@flow
```

**What it suggests:**
- P0: Urgent items (blockers, queue review)
- P1: High priority (pending handoff, recent work)
- P2: Normal tasks
- P3: Starting fresh

---

### `classify_memory`
**Purpose:** Determine memory type from content

**Parameters:**
- `content` (required)
- `filename` (optional) - Helps classification

**Example (used internally):**
```
Classifies "Use PostgreSQL" as Decision
Classifies "Bug in login" as Incident
```

---

### `start_session` (with smart selection)
**Purpose:** Enhanced start with auto-selection

**Features:**
- Auto-selects if only one context
- Offers recent session resume
- Shows context list if multiple

Used by `@start`

---

## 📊 Reporting

### `export_context`
**Purpose:** Export entire context as document

**Parameters:**
- `context_id` (required)
- `format` (required) - "markdown" or "json"

**Example:**
```
"Export current context as markdown"
```

**Output:** Complete dump of all memories, decisions, requirements

---

### `log_progress`
**Purpose:** Quick status update  
**Shortcut:** `@log "message"`

**Parameters:**
- `context_id` (required)
- `message` (required)
- `tags` (optional)

**Example:**
```
@log "Fixed authentication bug, testing now"
```

---

### `log_incident`
**Purpose:** Report production issue  
**Shortcut:** `@bug "description"`

**Parameters:**
- `context_id` (required)
- `title` (required)
- `description` (required)
- `severity` (required) - "critical", "high", "moderate", "low"
- `external_ref` (optional) - Link to ticket/dashboard

**Example:**
```
@bug "Login endpoint returns 500 on production"
```

---

### `record_deployment`
**Purpose:** Track deployments

**Parameters:**
- `context_id` (required)
- `environment` (required) - "prod", "staging", etc.
- `version` (required) - Version/commit SHA
- `status` (required) - "success", "failed", "partial"
- `external_ref` (optional) - CI/CD link

**Example:**
```
"Record deployment to production: version v2.1.0, status success"
```

---

### `record_review`
**Purpose:** Document code/design reviews

**Parameters:**
- `context_id` (required)
- `title` (required)
- `summary` (required)
- `status` (required) - "approved", "changes_requested", "pending"
- `external_ref` (optional) - PR link

**Example:**
```
"Record review: Login refactor, status approved, PR #123"
```

---

## 🔧 Utility Tools

### `list_shortcuts`
**Purpose:** See all available `@` commands  
**Shortcut:** `@help`

**Example:**
```
@help
```

---

### `list_by_tag`
**Purpose:** Find all memories with a specific tag

**Parameters:**
- `context_id` (required)
- `tag` (required)

**Example:**
```
"Show all memories tagged with 'bug'"
"Find all 'decision' tags"
```

---

### `prune_expired_memories`
**Purpose:** Clean up expired/temporary memories

**Example:**
```
"Prune expired memories"
```

---

### `validate_action`
**Purpose:** Check if action complies with project rules

**Parameters:**
- `context_id` (required)
- `content` (required) - Action to validate
- `mode` (optional) - "strict", "warn", "audit"

**Example (used internally):**
```
Validates: "Is this deployment allowed?" against project rules
```

---

## 📝 Notes for Developers

### Tool Naming Convention
All tools follow: `verb_noun` pattern
- `add_memory` - Add a memory
- `get_context` - Get a context
- `list_memories` - List memories

### Return Format
Tools return MCP-standard responses:
```json
{
  "content": [
    {
      "type": "text",
      "text": "Response message"
    }
  ],
  "isError": false
}
```

### Error Handling
Errors return`:
```json
{
  "content": [{
    "type": "text",
    "text": "Error: <description>"
  }],
  "isError": true
}
```

---

## 🆘 Need More Help?

- **Can't find the right tool?** Ask your AI assistant in natural language!
- **Want examples?** See [Getting Started](./getting-started.md)
- **Need concepts?** Read [Core Concepts](./concepts.md)
- **Having issues?** Check [Troubleshooting](./TROUBLESHOOTING.md)

---

**Remember:** You usually don't call these tools directly! Just ask your AI assistant in natural language, and it will use the right tool automatically.

For quick access, use the shortcuts (`@start`, `@note`, etc.) - they're faster and easier to remember! 🚀

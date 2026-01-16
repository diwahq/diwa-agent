# 🚀 Getting Started with Diwa Agent

This guide will walk you through your first session with Diwa. By the end, you'll understand how to use Diwa to enhance your AI coding experience!

---

## ✅ Before You Start

Make sure you've completed:
- ✅ [Installation](./INSTALLATION.md)
- ✅ Connected Diwa to your AI assistant (Claude Desktop, Cursor, etc.)
- ✅ Restarted your AI assistant

**To verify Diwa is working:**
Open your AI assistant and type `list_tools`. You should see "diwa" tools in the list.

---

## 🎯 Your First Session (10 Minutes)

### Step 1: Start a Session

In your AI assistant (Claude Desktop, Cursor, etc.), type:

```
@start
```

**What happens:**
- Diwa detects which project you're in (based on your current folder/git repo)
- If you have multiple projects, it asks you to choose
- If it's your first time, it helps you create a new context

**Example output:**
```
✓ Session started for context: my-project
Session ID: abc-123
No previous handoff found (this is your first session!)

Available shortcuts:
@note - Quick note
@decide - Record decision
@search - Find memories
@end - End session
```

### Step 2: Store Your First Memory

Let's store a simple fact about your project:

```
@note "This project uses TypeScript and React"
```

**What happens:**
- Diwa creates a new memory
- Auto-tags it based on content
- Timestamps it
- Associates it with your current context

**Example output:**
```
✓ Memory stored
ID: mem-456
Type: Note
Tags: [typescript, react, tech-stack]
```

### Step 3: Make a Decision

Now let's record an important decision:

```
@decide "Use PostgreSQL for database" because "Need JSON support and ACID compliance"
```

**What happens:**
- Diwa stores this as a "Decision" type memory
- Saves both the decision AND the reasoning
- This is searchable later!

**Example output:**
```
✓ Decision recorded
Decision: Use PostgreSQL for database
Rationale: Need JSON support and ACID compliance
Tags: [decision, database, postgresql]
```

### Step 4: Search Your Memories

Let's find what we just stored:

```
@search "database"
```

**What happens:**
- Diwa searches all memories in your current context
- Returns matching results with highlights

**Example output:**
```
Found 1 memory:

[Decision] Use PostgreSQL for database
Rationale: Need JSON support and ACID compliance
Created: 2 minutes ago
Tags: decision, database, postgresql
```

### Step 5: Add a Requirement

Let's add a project requirement:

```
Can you add a requirement that the app must support at least 1000 concurrent users?
```

**What happens:**
- Your AI assistant uses Diwa's `add_requirement` tool
- Stores it as a trackable requirement
- Can be marked complete later

**Example output:**
```
✓ Requirement added
Title: Support 1000 concurrent users
Priority: High
Status: Pending
```

### Step 6: End Your Session

When you're done working:

```
@end "Set up initial project structure and documented key decisions"
```

**What happens:**
- Diwa creates a "handoff note"
- Summary of what you did
- Includes next steps (if you specified any)
- This will show up next time you `@start`

**Example output:**
```
✓ Session ended
Handoff note created
Summary: Set up initial project structure and documented key decisions

Next time you start, you'll see this handoff note!
```

---

## 🎓 Understanding What You Just Did

Let's break down what happened:

### You Created a Context
Your project now has a "memory space" in Diwa where all knowledge is stored.

### You Stored Different Types of Memories
- **Note**: General fact ("Uses TypeScript and React")
- **Decision**: Choice with reasoning ("PostgreSQL because...")
- **Requirement**: Must-have feature ("Support 1000 users")

### You Made It Searchable
Everything you stored can be found later with `@search`.

### You Created Session Continuity
The handoff note means next time you'll know exactly where you left off!

---

## 🔄 Your Second Session (Resuming Work)

Let's see session continuity in action!

### Step 1: Resume

Open your AI assistant and type:

```
@resume
```

**What you'll see:**
```
📋 Resuming from last session:

Session Summary (Jan 15, 3:30 PM):
"Set up initial project structure and documented key decisions"

Recent Memories:
- [Decision] Use PostgreSQL for database
- [Requirement] Support 1000 concurrent users
- [Note] Uses TypeScript and React

Pending Tasks: 0
Active Blockers: 0
```

**Now you have full context!** You know:
- What you did last time
- What decisions were made
- What's still pending

### Step 2: Continue Working

Let's add more knowledge:

```
@note "Authentication will use JWT tokens"
```

```
@bug "Login button not responsive on mobile"
```

### Step 3: Check Project Status

See an overview of your project:

```
@status
```

**Example output:**
```
📊 Project Status: my-project

Memories: 5
├── Notes: 2
├── Decisions: 1
├── Requirements: 1
└── Blockers: 1

Recent Activity:
- [Bug] Login button not responsive on mobile (just now)
- [Note] Authentication uses JWT (1 min ago)
- ...

Health: Good ✓
```

---

## 💡 Common Workflows

### Workflow 1: Tracking a Feature

**Planning Phase:**
```
@requirement "Users must be able to reset passwords"
@note "Password reset link expires after 24 hours"
@decide "Send reset link via email" because "More secure than SMS"
```

**Implementation Phase:**
```
@note "Password reset endpoint: POST /auth/reset-password"
@note "Email template: templates/password-reset.html"
```

**Testing Phase:**
```
@bug "Reset link doesn't work for Gmail users"
```

**Completion:**
```
@note "Bug fixed - Gmail was blocking emails, added SPF record"
// Mark requirement as complete via AI assistant
```

### Workflow 2: Daily Development

**Morning Start:**
```
@start
@resume
// Review what you were doing
// See any blockers
```

**During Work:**
```
@note "..." // Store quick facts
@search "..." // Find previous decisions
@decide "..." // Record new choices
```

**End of Day:**
```
@end "Completed user auth, started password reset. Tomorrow: finish reset flow"
```

### Workflow 3: Debugging

**When you hit a problem:**
```
@bug "App crashes when uploading files >5MB"
@search "upload" // Find related code/decisions
```

**When you solve it:**
```
@note "Fixed: Increased upload limit in nginx config"
@lesson "Always test with large files before deploying"
```

---

## 🎯 Pro Tips

### 1. Queue Handoff Items as You Work

Instead of trying to remember everything for `@end`:

```
@note "Important progress note"  // Automatically queued
@note "this" // Quick capture of current work
```

At end of session, these are automatically included!

### 2. Use Search Creatively

```
@search "database"          // Find database-related memories
@search tag:decision        // All decisions
@search tag:bug tag:auth    // Bugs related to auth
```

### 3. Check Status Regularly

```
@status  // Quick health check
```

Helps you see:
- How many pending tasks
- Any blockers
- Recent activity

### 4. Use Workflow Detection

```
@flow
```

Diwa analyzes your project and suggests what to do next!

---

## 🆘 Troubleshooting

### "Diwa doesn't detect my project"

**Solution:** Explicitly create a context:
```
Can you create a new context called "my-project"?
```

Then bind it to your directory:
```
Can you bind this directory to the "my-project" context?
```

### "I can't find a memory I stored"

**Try different searches:**
```
@search "partial keyword"
@search tag:note
@history  // See recent changes
```

### "I made a mistake"

**Edit a memory:**
```
Can you update memory XYZ to say "corrected information"?
```

**Delete a memory:**
```
Can you delete memory XYZ?
```

### "Nothing works!"

1. Check Diwa is running: `list_tools` should show diwa tools
2. Restart your AI assistant
3. See [Troubleshooting Guide](./TROUBLESHOOTING.md)

---

## 🎓 What's Next?

You now know the basics! Here's how to level up:

### Learn More Shortcuts
→ [Shortcuts Reference](./shortcuts.md)

### Understand the Concepts  
→ [Core Concepts](./concepts.md)

### See All Available Tools
→ [Tools Reference](./TOOLS.md)

### Advanced Organization
→ [Project Organization Guide](./PROJECT_ORGANIZATION.md)

---

## 📝 Quick Reference Card

Save this for easy access:

```
Essential Commands:
@start           - Begin session
@resume          - See last handoff
@note "..."      - Quick memory
@decide "..." because "..."  - Record decision
@bug "..."       - Track problem
@search "..."    - Find memories
@status          - Project overview
@queue          - See queued items
@end "..."       - End session with summary

Pro Commands:
@flow            - What should I do next?
@history         - Recent changes
@revise <id> "..." - Edit memory
```

---

**Congratulations!** 🎉 You're now ready to use Diwa effectively. Remember:
- **Use it regularly** - The more you store, the more valuable it becomes
- **Trust the system** - Diwa will help you find things
- **Start simple** - Don't overthink it!

Happy coding! 🚀

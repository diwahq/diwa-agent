# 📖 Diwa Agent Documentation

Welcome to Diwa Agent! This guide will help you get started, whether you're a developer or someone completely new to AI coding assistants.

---

## 🎯 What is Diwa Agent?

**Diwa Agent is like a notebook that your AI assistant can read and write to.**

Imagine you're working with an AI coding assistant (like Claude, Cursor, or Windsurf). Every time you start a new conversation, the AI forgets everything from your previous chat. You have to re-explain:
- What your project does
- Decisions you've already made  
- Problems you've already solved
- Requirements you need to follow

**Diwa Agent solves this.** It gives your AI assistant a permanent memory that:
- ✅ **Remembers your decisions** - "We chose PostgreSQL for the database"
- ✅ **Tracks your requirements** - "Must support 1000 concurrent users"
- ✅ **Stores your notes** - "The API endpoint is /api/v2/users"
- ✅ **Keeps your project organized** - Auto-detects which project you're working on

And it all stays **on your computer** - no cloud required!

---

## 📚 Table of Contents

### Getting Started
1. [Installation Guide](./INSTALLATION.md) - Set up Diwa Agent in 5 minutes
2. [First Steps](./getting-started.md) - Your first session with Diwa
3. [MCP Setup](./mcp-setup.md) - Connect to Claude Desktop, Cursor, or Windsurf

### Using Diwa
4. [Shortcuts Reference](./shortcuts.md) - Quick `@` commands you can use
5. [Tools Reference](./TOOLS.md) - All 40+ available tools
6. [Workflow Guide](./workflows.md) - How to use Diwa effectively

### Understanding Diwa
7. [Core Concepts](./concepts.md) - Contexts, Memories, and Sessions explained simply
8. [Project Organization](./PROJECT_ORGANIZATION.md) - How to organize multiple projects
9. [Data Format](./data-format.md) - How your data is stored

### Advanced Topics
10. [Troubleshooting](./TROUBLESHOOTING.md) - Common issues and solutions
11. [Migration Guide](./migration.md) - Upgrade to Diwa Cloud (Enterprise)
12. [Docker Setup](./DOCKER.md) - Run Diwa in a container

---

## ⚡ Quick Start (5 Minutes)

### What You Need
- A Mac or Linux computer (Windows WSL works too!)
- An AI assistant that supports MCP (like Claude Desktop)
- 5 minutes

### Installation Steps

**1. Install Prerequisites**
```bash
# On Mac with Homebrew
brew install elixir

# On Ubuntu/Debian
sudo apt-get install elixir

# Verify installation
elixir --version  # Should show 1.16 or higher
```

**2. Download Diwa Agent**
```bash
git clone https://github.com/diwahq/diwa-agent.git
cd diwa-agent
```

**3. Set Up Diwa**
```bash
mix deps.get    # Download dependencies (1-2 min)
mix ecto.setup  # Create database
```

**4. Connect to Your AI Assistant**

For Claude Desktop, edit this file:  
`~/Library/Application Support/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "diwa": {
      "command": "mix",
      "args": ["run", "--no-halt"],
      "cwd": "/Users/YOUR_USERNAME/path/to/diwa-agent"
    }
  }
}
```

**Important:** Change `/Users/YOUR_USERNAME/path/to/diwa-agent` to your actual path!

**5. Restart Claude Desktop**

### Try It!

In Claude Desktop, type:
```
@start
```

Claude will say "Session started!" 🎉

Now try:
```
@note "This is my first Diwa memory!"
@search "first"
```

You should see your note appear!

---

## 💡 How It Works (Simple Explanation)

### Think of Diwa as Three Things:

**1. A Notebook 📓**
- You (through your AI) can write notes
- Notes are organized by project
- Notes can be searched anytime

**2. A Memory System 🧠**
- Remembers decisions you made
- Tracks requirements you set
- Stores lessons you learned

**3. A Project Manager 📊**
- Knows which project you're working on
- Keeps each project's notes separate
- Auto-detects projects from git repos

### When You Use Diwa:

1. **You start a session** (`@start`)
   - Diwa figures out which project you're in
   - Shows you what you were doing last time

2. **You work and store knowledge**
   - `@note "API uses JWT tokens"` → Stores a fact
   - `@decide "Use React" because "Team knows it"` → Records a decision
   - `@bug "Login fails on Safari"` → Tracks an issue

3. **You end the session** (`@end`)
   - Diwa creates a "handoff note" for next time
   - Includes what you did and what's next

4. **Next session:**
   - `@resume` shows you where you left off
   - All your notes are searchable
   - AI assistant has full context!

---

## 🎓 Learning Path

### For Complete Beginners
1. Read [Core Concepts](./concepts.md) - Understand the basics
2. Follow [Getting Started](./getting-started.md) - Hands-on tutorial
3. Learn [Basic Shortcuts](./shortcuts.md) - 10 commands to know
4. Try [Example Workflows](./workflows.md) - See real examples

### For Developers
1. Skim [Installation](./INSTALLATION.md) - Quick setup
2. Check [MCP Setup](./mcp-setup.md) - Configure your editor
3. Browse [Tools Reference](./TOOLS.md) - All available commands
4. Read [Project Organization](./PROJECT_ORGANIZATION.md) - Best practices

### For Teams
1. Start with Diwa Agent (this version)
2. Read [Migration Guide](./migration.md)
3. Consider [Diwa Cloud](https://diwa.one) for shared team memory

---

## 🆘 Need Help?

### Common Questions

**Q: Will this slow down my AI assistant?**  
A: No! Diwa runs locally and is very fast (SQLite database).

**Q: Is my data sent to the cloud?**  
A: No! Everything stays on your computer.

**Q: Do I need to be a programmer?**  
A: No! If you can use shortcuts like `@note`, you can use Diwa.

**Q: What if I mess something up?**  
A: Diwa keeps version history. You can undo changes!

### Getting Support

- 📖 Check [Troubleshooting Guide](./TROUBLESHOOTING.md)
- 💬 Open a [GitHub Issue](https://github.com/diwahq/diwa-agent/issues)
- 🌐 Visit [diwa.one](https://diwa.one) for more resources

---

## 🎯 What's Next?

Choose your path:

- **Just starting?** → [Installation Guide](./INSTALLATION.md)
- **Want to understand it?** → [Core Concepts](./concepts.md)
- **Ready to use it?** → [Getting Started](./getting-started.md)
- **Need specific help?** → [Troubleshooting](./TROUBLESHOOTING.md)

---

**Remember:** Diwa Agent is here to make your AI assistant smarter by giving it a memory. Start simple, and you'll quickly see the value!

Questions? We're here to help! 🚀

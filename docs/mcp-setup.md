# 🔧 MCP Setup Guide

This guide shows you how to connect Diwa Agent to different AI assistants using the Model Context Protocol (MCP).

---

## What is MCP?

**MCP (Model Context Protocol)** is a standard way for AI assistants to use external tools. Think of it like a universal plug that lets any MCP-compatible AI assistant use Diwa.

**Supported AI Assistants:**
- ✅ Claude Desktop (Anthropic)
- ✅ Cursor (AI Code Editor)  
- ✅ Windsurf (Codeium)
- ✅ Any MCP-compatible client

---

## 📱 Claude Desktop Setup

### Step 1: Find Your Config File

The location depends on your operating system:

**macOS:**
```
~/Library/Application Support/Claude/claude_desktop_config.json
```

**Windows:**
```
%APPDATA%\Claude\claude_desktop_config.json
```

**Linux:**
```
~/.config/Claude/claude_desktop_config.json
```

### Step 2: Edit the Config

Open the file in a text editor. If it doesn't exist, create it with:

```json
{
  "mcpServers": {}
}
```

### Step 3: Add Diwa Configuration

Add the Diwa server configuration:

```json
{
  "mcpServers": {
    "diwa": {
      "command": "mix",
      "args": ["run", "--no-halt"],
      "cwd": "/absolute/path/to/diwa-agent"
    }
  }
}
```

**⚠️ Important:** Replace `/absolute/path/to/diwa-agent` with your actual path!

**To find your path:**
```bash
cd diwa-agent
pwd
# Copy the output and use it in the config
```

### Step 4: Restart Claude Desktop

Completely quit and restart Claude Desktop (don't just close the window).

### Step 5: Verify

In Claude Desktop, type:
```
list_tools
```

You should see Diwa tools in the list! Look for tools like:
- `diwa.start_session`
- `diwa.add_memory`
- `diwa.search_memories`

### Troubleshooting Claude Desktop

**❌ "No tools found"**
- Check the path in your config (must be absolute  path)
- Make sure Elixir is installed: `elixir --version`
- Check Claude's logs (Help → Show Logs)

**❌ "Command not found: mix"**
- Elixir is not installed or not in PATH
- Install Elixir: `brew install elixir` (macOS)

**❌ "Database locked" error**
- Close any other terminal windows running Diwa
- Delete `_build` folder and restart

---

## 💻 Cursor Setup

### Step 1: Find Cursor Config

**Location varies by OS:**

**macOS:**
```
~/.cursor/mcp_config.json
```

**Windows:**
```
%USERPROFILE%\.cursor\mcp_config.json
```

**Linux:**
```
~/.cursor/mcp_config.json
```

### Step 2: Add Diwa Configuration

Create or edit the file:

```json
{
  "mcpServers": {
    "diwa": {
      "command": "mix",
      "args": ["run", "--no-halt"],
      "cwd": "/absolute/path/to/diwa-agent",
      "env": {}
    }
  }
}
```

### Step 3: Restart Cursor

Completely restart Cursor (Cmd+Q on Mac, then reopen).

### Step 4: Verify

In Cursor's AI chat, type:
```
@start
```

You should see Diwa respond!

### Cursor-Specific Tips

**Enable MCP in Settings:**
1. Open Cursor Settings (Cmd+,)
2. Search for "MCP"
3. Enable "Model Context Protocol"

**View MCP Status:**
- Look for MCP indicator in status bar
- Check if Diwa is connected (green dot)

---

## 🌊 Windsurf Setup

### Step 1: Open Windsurf Settings

1. Click on Settings (⚙️ icon)
2. Go to "Extensions" or "MCP Servers"

### Step 2: Add Diwa Server

Add a new MCP server with:

**Name:** `diwa`

**Command:** `mix`

**Arguments:** `run --no-halt`

**Working Directory:** `/absolute/path/to/diwa-agent`

### Step 3: Restart Windsurf

Close and reopen Windsurf.

### Step 4: Verify

In Windsurf chat:
```
@start
```

---

## 🛠️ Advanced Configuration

### Environment Variables

You can pass environment variables to Diwa:

```json
{
  "mcpServers": {
    "diwa": {
      "command": "mix",
      "args": ["run", "--no-halt"],
      "cwd": "/path/to/diwa-agent",
      "env": {
        "MIX_ENV": "prod",
        "DATABASE_PATH": "/custom/path/to/database"
      }
    }
  }
}
```

### Multiple Contexts (Advanced)

You can run multiple Diwa instances for different projects:

```json
{
  "mcpServers": {
    "diwa-work": {
      "command": "mix",
      "args": ["run", "--no-halt"],
      "cwd": "/path/to/diwa-agent",
      "env": {
        "DATABASE_PATH": "/path/to/work.db"
      }
    },
    "diwa-personal": {
      "command": "mix",
      "args": ["run", "--no-halt"],
      "cwd": "/path/to/diwa-agent",
      "env": {
        "DATABASE_PATH": "/path/to/personal.db"
      }
    }
  }
}
```

### Using a Custom Port

If you want Diwa to use a specific port:

```json
{
  "mcpServers": {
    "diwa": {
      "command": "mix",
      "args": ["run", "--no-halt"],
      "cwd": "/path/to/diwa-agent",
      "env": {
        "PORT": "4000"
      }
    }
  }
}
```

---

## 🐛 Common Issues

### Issue: "MCP server not responding"

**Possible causes:**
1. Path is incorrect
2. Elixir not installed
3. Database permissions issue

**Solutions:**
```bash
# 1. Verify path
cd /path/from/config
pwd  # Should match config exactly

# 2. Check Elixir
elixir --version

# 3. Fix permissions
cd diwa-agent
chmod +x diwa.sh
```

### Issue: "Database locked"

**Cause:** Multiple Diwa instances running

**Solution:**
```bash
# Kill existing Diwa processes
pkill -f "mix run"

# Restart your AI assistant
```

### Issue: "Tools not showing up"

**Checklist:**
- ✅ Config file has correct JSON syntax
- ✅ Absolute path is used (not relative like `~/`)
- ✅ AI assistant was fully restarted
- ✅ Elixir is in PATH

**Test manually:**
```bash
cd /path/to/diwa-agent
mix run --no-halt
# Should start without errors
```

### Issue: "Permission denied"

**On macOS:**
```bash
# Give Terminal full disk access
System Preferences → Security & Privacy → Privacy → Full Disk Access
# Add Terminal.app
```

**On Linux:**
```bash
# Make sure you own the files
sudo chown -R $USER:$USER /path/to/diwa-agent
```

---

## 🧪 Testing Your Setup

### Quick Test

1. **Start your AI assistant** (Claude Desktop, Cursor, etc.)

2. **List tools:**
   ```
   list_tools
   ```
   Should show Diwa tools

3. **Start a session:**
   ```
   @start
   ```
   Should create/detect a context

4. **Store a memory:**
   ```
   @note "Testing Diwa setup"
   ```
   Should succeed

5. **Search:**
   ```
   @search "testing"
   ```
   Should find your note

**If all 5 steps work, you're good to go!** ✅

---

## 📊 Verifying Connection

### Check MCP Status

**In Claude Desktop:**
- Look at bottom-right status bar
- Should show "MCP: Connected" or similar
- Number of active tools/servers

**In Cursor:**
- Status bar shows MCP indicator
- Click it to see connected servers

**Via Commands:**
```
list_tools        # Should show diwa tools
@start            # Should work without errors
```

### View Diwa Logs

**Check if Diwa is running:**
```bash
ps aux | grep "mix run"
```

**View logs:**
```bash
cd diwa-agent
tail -f log/dev.log  # If logging enabled
```

---

## 💡 Best Practices

### 1. Use Absolute Paths

**❌ Don't use:**
```json
"cwd": "~/diwa-agent"
"cwd": "./diwa-agent"
```

**✅ Use:**
```json
"cwd": "/Users/yourname/projects/diwa-agent"
```

### 2. Keep Config Backed Up

Your MCP config is important! Save a copy:
```bash
cp ~/Library/Application\ Support/Claude/claude_desktop_config.json ~/claude_backup.json
```

### 3. Test After Updates

After updating your AI assistant:
```
@start  # Quick test
```

### 4. One Instance Per Database

Don't try to run multiple MCP servers pointing to the same database file.

---

## 🔄 Updating Diwa

When you update Diwa Agent:

1. **Pull updates:**
   ```bash
   cd diwa-agent
   git pull
   ```

2. **Update dependencies:**
   ```bash
   mix deps.get
   mix ecto.migrate
   ```

3. **Restart AI assistant**
   - Fully quit and reopen

4. **Test:**
   ```
   @start
   ```

---

## 🆘 Need Help?

**Still stuck?**

1. Check [Troubleshooting Guide](./TROUBLESHOOTING.md)
2. Verify [Installation](./INSTALLATION.md) was completed
3. Open an issue: [GitHub Issues](https://github.com/diwahq/diwa-agent/issues)

**Include in your report:**
- Operating system (macOS/Windows/Linux)
- AI assistant (Claude/Cursor/Windsurf)
- Output of `elixir --version`
- Your config file (remove personal paths)

---

**✅ Setup Complete!**

Once Diwa is connected, head to:
- [Getting Started Guide](./getting-started.md) - Learn how to use Diwa
- [Shortcuts Reference](./shortcuts.md) - Quick command reference
- [Core Concepts](./concepts.md) - Understand how Diwa works

Happy coding! 🚀

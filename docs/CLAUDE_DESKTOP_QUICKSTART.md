# Quick Start: Claude Desktop Integration

**5-Minute Setup Guide**

---

## 1️⃣ Get the Absolute Path

```bash
cd /Users/ei/codes/diwa
pwd
# Copy the output
```

## 2️⃣ Edit Claude Config

Open:
```bash
open ~/Library/Application\ Support/Claude/claude_desktop_config.json
```

Add this (replace with YOUR path):
```json
{
  "mcpServers": {
    "diwa": {
      "command": "/Users/ei/codes/diwa/diwa.sh",
      "args": ["start"]
    }
  }
}
```

## 3️⃣ Restart Claude Desktop

1. Quit Claude Desktop (Cmd+Q)
2. Wait 5 seconds
3. Reopen Claude Desktop

## 4️⃣ Verify Connection

Look for the 🔨 hammer icon in Claude Desktop.
Click it → Should see "diwa" with 47 tools.

## 5️⃣ Quick Test

Ask Claude in the chat:
```
Create a new Diwa context called "Test" and add a memory "Hello from Claude Desktop!"
```

If it works, you're done! ✅

---

## 🐛 If It Doesn't Work

**Check Diwa is running**:
```bash
ps aux | grep diwa
```

**Check logs**:
```bash
tail -f ~/Library/Logs/Claude/mcp*.log
```

**Restart Diwa**:
```bash
pkill -f diwa
./diwa.sh start
```

**Verify config syntax**:
```bash
cat ~/Library/Application\ Support/Claude/claude_desktop_config.json | jq .
```

---

## ✅ Success = Diwa appears in 🔨 menu with 47 tools

See `.agent/claude_desktop_integration_testing.md` for comprehensive testing guide.

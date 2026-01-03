# Diwa Project Organization

**Preferred file organization structure for the Diwa project**

---

## 📁 Directory Structure

```
diwa/
├── .agent/                    # Planning & session documentation
│   ├── *.md                   # Design decisions, status, plans
│   └── workflows/             # Workflow definitions
│
├── .claude/                   # Claude Desktop configuration
│   └── settings.local.json
│
├── config/                    # Application configuration
│   ├── config.exs             # Base configuration
│   ├── dev.exs                # Development config
│   ├── test.exs               # Test config
│   └── prod.exs               # Production config
│
├── docs/                      # 📚 User-facing documentation
│   ├── USAGE.md               # Usage guide
│   ├── QUICKREF.md            # Quick reference
│   ├── STARTUP_MODES.md       # Startup modes explained
│   └── CLAUDE_DESKTOP_QUICKSTART.md
│
├── lib/diwa/                  # Application source code
│   ├── application.ex         # OTP application
│   ├── cli.ex                 # CLI interface
│   ├── server.ex              # MCP server
│   ├── protocol/              # MCP protocol implementation
│   ├── storage/               # Database layer
│   ├── tools/                 # MCP tool definitions
│   └── web/                   # Web dashboard
│
├── logs/                      # 📋 Log files (gitignored)
│   ├── *.log                  # Application logs
│   └── erl_crash.dump         # Erlang crash dumps
│
├── priv/                      # Private application files
│   └── repo/                  # Database migrations & seeds
│
├── scripts/                   # Utility scripts
│   ├── *.exs                  # Elixir scripts
│   └── *.sh                   # Shell scripts
│
├── test/                      # Test files
│   └── diwa/                  # Test modules
│
├── test_data/                 # 🧪 Test fixtures & samples (gitignored)
│   ├── *.json                 # JSON test files
│   └── *.jsonl                # JSONL test files
│
├── tmp/                       # Temporary files (gitignored)
│
├── README.md                  # Main project documentation
├── mix.exs                    # Project definition
├── mix.lock                   # Dependency lock file
└── diwa.sh                    # Startup script
```

---

## 📂 Folder Purposes

### `/docs` - Documentation
**Purpose**: User-facing documentation  
**Contents**: Guides, references, tutorials  
**Committed**: ✅ Yes

**Files**:
- `USAGE.md` - How to use Diwa
- `QUICKREF.md` - Quick reference for all tools
- `STARTUP_MODES.md` - Explanation of startup modes
- `CLAUDE_DESKTOP_QUICKSTART.md` - Quick setup guide

### `/logs` - Log Files
**Purpose**: Runtime logs and crash dumps  
**Contents**: Application logs, error logs, crash dumps  
**Committed**: ❌ No (gitignored)

**Files**:
- `*.log` - Application log files
- `erl_crash.dump` - Erlang VM crash dumps
- `diwa_mcp.log` - MCP server logs

### `/test_data` - Test Fixtures
**Purpose**: Test data and sample files  
**Contents**: JSON fixtures, test inputs, mock responses  
**Committed**: ❌ No (gitignored)

**Files**:
- `*.json` - JSON test fixtures
- `*.jsonl` - JSONL test data
- Sample MCP requests/responses

### `/scripts` - Utility Scripts
**Purpose**: Development and maintenance scripts  
**Contents**: Setup scripts, recording scripts, utilities  
**Committed**: ✅ Yes

**Files**:
- `*.exs` - Elixir scripts (e.g., recording work in Diwa)
- `*.sh` - Shell scripts (e.g., setup, installation)

### `/.agent` - Planning & Documentation
**Purpose**: Development planning and session tracking  
**Contents**: Design decisions, status updates, plans  
**Committed**: ✅ Yes

**Files**:
- Design decisions
- Implementation plans
- Session summaries
- Workflow definitions

### `/tmp` - Temporary Files
**Purpose**: Temporary working files  
**Contents**: Build artifacts, temporary data  
**Committed**: ❌ No (gitignored)

---

## 🎯 File Organization Rules

### Root Directory
**Keep minimal** - Only essential files:
- ✅ `README.md` - Main documentation
- ✅ `mix.exs` - Project definition
- ✅ `mix.lock` - Dependencies
- ✅ `diwa.sh` - Startup script
- ✅ `.gitignore` - Git ignore rules
- ✅ `.formatter.exs` - Code formatter config

**Move elsewhere**:
- ❌ Documentation → `/docs`
- ❌ Logs → `/logs`
- ❌ Test data → `/test_data`
- ❌ Scripts → `/scripts`
- ❌ Config → `/config`

### Documentation Files
**Location**: `/docs`  
**Naming**: `UPPERCASE_WITH_UNDERSCORES.md`  
**Examples**: `USAGE.md`, `QUICKREF.md`, `STARTUP_MODES.md`

### Log Files
**Location**: `/logs`  
**Naming**: `lowercase_with_underscores.log`  
**Examples**: `diwa_mcp.log`, `server.log`, `error.log`

### Test Data
**Location**: `/test_data`  
**Naming**: `descriptive_name.json` or `descriptive_name.jsonl`  
**Examples**: `init.json`, `test_input.jsonl`, `backup.json`

### Scripts
**Location**: `/scripts`  
**Naming**: 
- Elixir: `verb_noun.exs` (e.g., `record_work.exs`)
- Shell: `verb-noun.sh` (e.g., `setup-database.sh`)

---

## 🔄 Migration Guide

When adding new files, follow this decision tree:

```
Is it documentation?
├─ Yes → /docs
└─ No
   ├─ Is it a log file?
   │  ├─ Yes → /logs
   │  └─ No
   │     ├─ Is it test data?
   │     │  ├─ Yes → /test_data
   │     │  └─ No
   │     │     ├─ Is it a script?
   │     │     │  ├─ Yes → /scripts
   │     │     │  └─ No
   │     │     │     ├─ Is it config?
   │     │     │     │  ├─ Yes → /config
   │     │     │     │  └─ No → Root (if essential) or /tmp
```

---

## 🧹 Cleanup Checklist

When organizing files:

- [ ] Move all `*.md` (except README.md) to `/docs`
- [ ] Move all `*.log` and crash dumps to `/logs`
- [ ] Move all test `*.json` and `*.jsonl` to `/test_data`
- [ ] Move all `*.sh` and `*.exs` scripts to `/scripts`
- [ ] Move config files to `/config`
- [ ] Update `.gitignore` to ignore `/logs` and `/test_data`
- [ ] Update README.md links if needed
- [ ] Record organization in Diwa context

---

## 📊 Benefits

### Clean Root Directory
- ✅ Easy to navigate
- ✅ Professional appearance
- ✅ Clear project structure
- ✅ Faster file discovery

### Organized Folders
- ✅ Logical grouping
- ✅ Easy to find files
- ✅ Consistent structure
- ✅ Scalable organization

### Proper Gitignore
- ✅ No log files in repo
- ✅ No test data in repo
- ✅ Clean git status
- ✅ Smaller repository size

---

## 🎯 Maintenance

### Regular Cleanup
Run this periodically to keep the project organized:

```bash
# Move any stray log files
mv *.log logs/ 2>/dev/null || true

# Move any stray JSON test files
mv *_resp.json test_data/ 2>/dev/null || true
mv test_*.json test_data/ 2>/dev/null || true

# Clean up crash dumps
mv erl_crash.dump logs/ 2>/dev/null || true

# Check for files in root
ls -la | grep "^-" | awk '{print $9}'
```

### Before Committing
Always check:
```bash
git status
# Should not show logs/, test_data/, or tmp/
```

---

## 📝 Recording in Diwa

This organization structure is recorded in Diwa's context as the **preferred way to organize files** in this project. Future file additions should follow this structure.

---

**Last Updated**: December 26, 2025  
**Status**: ✅ Implemented and Documented

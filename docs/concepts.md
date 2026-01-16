# 🎓 Core Concepts - Understanding Diwa

This guide explains the main ideas behind Diwa Agent in simple terms. No technical jargon!

---

## 🗂️ What is a Context?

**Think of a Context as a project folder.**

Just like you might have different folders on your computer for different projects (one for work, one for a personal website, one for learning), Diwa uses "Contexts" to keep your projects separate.

### Example:
```
Your Projects:
├── 📁 work-app (Context)
│   ├── "We use PostgreSQL"
│   ├── "Login timeout is 30 min"
│   └── "Deploy on Fridays"
│
├── 📁 personal-blog (Context)
│   ├── "Built with Next.js"
│   ├── "Uses Markdown for posts"
│   └── "Hosted on Vercel"
│
└── 📁 learning-python (Context)
    ├── "Following tutorial X"
    ├── "Using Python 3.12"
    └── "Goal: Build a web scraper"
```

### Why Contexts Matter

Without contexts:
- All your notes would be mixed together
- You'd see blog notes while working on your app
- Very confusing! 😵

With contexts:
- ✅ Work notes stay with work
- ✅ Personal notes stay separate
- ✅ Diwa knows which project you're in
- ✅ AI only sees relevant info

### How Diwa Detects Your Context

Diwa is smart! It figures out which project you're in by looking at:

1. **Git repository** - "This folder is linked to github.com/you/work-app"
2. **Directory path** - "You're in /home/you/projects/personal-blog"
3. **Manual choice** - You can tell it directly

**Most of the time, you don't need to think about this.** Diwa just knows!

---

## 💾 What is a Memory?

**A Memory is any piece of knowledge you store.**

It could be:
- A quick note: "The API key is in .env file"
- A decision: "We chose React because the team knows it"
- A requirement: "Must support mobile devices"
- A lesson: "Don't deploy on Fridays!"
- A problem: "Bug: Login button doesn't work on Safari"

### Anatomy of a Memory

Every memory has:

**Content** - The actual information
```
"We decided to use PostgreSQL for the database"
```

**Timestamp** - When you stored it
```
2024-01-15 10:30 AM
```

**Tags** - Categories (automatic + manual)
```
[decision, database, backend]
```

**Context** - Which project it belongs to
```
work-app
```

**Type** - What kind of memory
```
Decision
```

### Memory Types Explained

Diwa automatically categorizes your memories:

| Type | What It Is | Example |
|------|------------|---------|
| **Note** | General fact | "API endpoint is /users" |
| **Decision** | Choice you made | "Using MongoDB" |
| **Requirement** | Must-have feature | "Support 1000 users" |
| **Lesson** | Something you learned | "Always test on mobile" |
| **Blocker** | Problem stopping you | "Can't deploy: permissions issue" |
| **Pattern** | Reusable solution | "Use this auth flow for all pages" |

**You don't need to specify the type!** Diwa figures it out from what you write.

---

## 🔄 What is a Session?

**A Session is one work period with your AI assistant.**

It's like a conversation that has a beginning and an end.

### Session Lifecycle

**1. Start (`@start`)**
```
You: @start
Diwa: ✓ Session started for work-app
      Last session: Yesterday at 3 PM
      You were working on: Login feature
      Next steps: Add password reset
```

**2. Work & Store Knowledge**
```
You: @note "Login uses JWT tokens"
You: @decide "Use bcrypt for passwords" because "Industry standard"
You: @bug "Logout button not working"
```

**3. End (`@end "summary"`)**
```
You: @end "Finished login feature, tested locally"
Diwa: ✓ Session ended. Handoff note created.
```

**4. Next Time (`@resume`)**
```
You: @resume
Diwa: Last session (Jan 15):
      ✓ Finished login feature
      ⚠ Bug: Logout button not working
      → Next: Add password reset
```

### Why Sessions Help

**Without sessions:**
- No record of what you did
- Forget where you left off
- Repeat the same work

**With sessions:**
- ✅ Clear start and stop points
- ✅ Handoff notes guide you
- ✅ AI knows what's done vs. what's next
- ✅ Track progress over time

---

## 🏷️ What are Tags?

**Tags are labels that help you find things later.**

They're like sticky notes you put on memories to group related information.

### Automatic Tags

Diwa adds tags automatically:
- `decision` - For choices you made
- `blocker` - For problems
- `requirement` - For must-haves
- `handoff_item` - For session notes

### Custom Tags

You can add your own:
```
@note "API uses REST" #backend #api #documentation
```

Now you can find it with:
```
@search tag:backend
@search tag:api
```

### Why Tags Are Useful

Imagine you have 100 memories. How do you find:
- All decisions about the database?
- All bugs related to login?
- All requirements for the mobile app?

**Tags make this easy:**
```
@search tag:decision tag:database
@search tag:bug tag:login  
@search tag:requirement tag:mobile
```

---

## 🔗 What are Relationships?

**Relationships connect related memories.**

Sometimes memories are connected:
- A decision might lead to a requirement
- A bug might block a feature
- A lesson might come from fixing a bug

### Example

```
Memory 1: Decision
"Use PostgreSQL for database"
    ↓
Memory 2: Requirement  
"Must handle 10,000 concurrent connections"
    ↓
Memory 3: Note
"Connection pooling configured in config/database.yml"
```

These are **linked** - one led to the next.

### Why This Matters

When you search for "PostgreSQL", Diwa can show:
- The original decision
- Related requirements
- Implementation notes
- All connected!

**You usually don't need to create links manually.** Diwa does it!

---

## 🎯 Putting It All Together

Let's see how everything works together:

### Real Example: Building a Blog

**1. Start Project**
```
@start
→ Creates new Context: "personal-blog"
```

**2. Store Knowledge**
```
@decide "Use Next.js" because "Fast and SEO-friendly"
→ Creates Decision memory with tags [decision, framework]

@note "Blog posts stored in /content/posts directory"
→ Creates Note memory

@requirement "Must support Markdown and code highlighting"
→ Creates Requirement memory
```

**3. Work & Update**
```
@search "markdown"
→ Finds your requirement about Markdown

@bug "Code blocks don't render correctly"
→ Creates Blocker memory
```

**4. End Session**
```
@end "Set up Next.js blog, added Markdown support. Code highlighting still broken."
→ Creates Handoff memory
```

**5. Next Session**
```
@resume
→ Shows: "Last session: Added Markdown support"
→ Shows: "Next: Fix code highlighting"
→ Shows: "Blocker: Code blocks don't render"
```

---

## 🤔 Common Questions

### "Do I need to organize my memories?"
**No!** Diwa does it automatically with:
- Auto-detection of contexts
- Auto-tagging
- Auto-classification
- Timestamps

### "What if I misspell something?"
**No problem!** Search works even if you:
- Spell things differently
- Use partial words
- Don't remember exact wording

### "Can I have multiple contexts?"
**Yes!** As many as you want. Each project gets its own context.

### "Do memories expire?"
**No!** They stay forever unless you delete them.

### "Can I edit memories?"
**Yes!** Use `@revise <memory-id> "new content"`

### "How do I see all my memories?"
```
@search "*"           # All memories
@status               # Project overview
@history             # Recent changes
```

---

## 🎓 Next Steps

Now that you understand the concepts:

1. **Try it yourself** → [Getting Started Guide](./getting-started.md)
2. **Learn shortcuts** → [Shortcuts Reference](./shortcuts.md)
3. **See examples** → [Workflow Guide](./workflows.md)

---

**Remember:** You don't need to memorize all this! Just know:
- **Contexts** = Projects
- **Memories** = Notes/Decisions/Facts
- **Sessions** = Work periods
- **Tags** = Labels for finding things

The rest will make sense as you use Diwa! 🚀

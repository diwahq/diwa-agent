# 🎯 Workflow Guide - Using Diwa Effectively

This guide shows you practical workflows for common scenarios. Real examples you can use today!

---

## 📋 Table of Contents

1. [Daily Development Workflow](#daily-development-workflow)
2. [Feature Planning Workflow](#feature-planning-workflow)
3. [Bug Tracking Workflow](#bug-tracking-workflow)
4. [Learning/Research Workflow](#learningresearch-workflow)
5. [Code Review Workflow](#code-review-workflow)
6. [Team Handoff Workflow](#team-handoff-workflow)
7. [Multiple Project Workflow](#multiple-project-workflow)

---

## 🌅 Daily Development Workflow

**Goal:** Track daily work and maintain continuity

### Morning Routine (5 minutes)

**1. Start your session:**
```
@start
```

**2. Review yesterday:**
```
@resume
```

You'll see:
- What you finished yesterday
- What you planned to do next
- Any open blockers

**3. Plan today:**
```
@note "Today: Finish authentication + Fix Safari bug"
```

### During Work

**Quick notes as you go:**
```
@note "JWT tokens expire after 24 hours"
@note "Auth endpoint: POST /api/auth/login"
```

**Record decisions:**
```
@decide "Use httpOnly cookies for JWT" because "Prevents XSS attacks"
```

**Track problems:**
```
@bug "Safari: Login button doesn't respond"
```

### End of Day (3 minutes)

**1. Review what you did:**
```
@queue  # See what you queued
```

**2. End session:**
```
@end "Completed authentication flow. JWT working. Safari bug still open."
```

**Next**: Tomorrow's `@resume` will show this!

---

## 🎨 Feature Planning Workflow

**Goal:** Plan and track a new feature from start to finish

### Planning Phase

**1. Define requirements:**
```
@requirement "Password reset" "Users must be able to reset forgotten passwords via email"
```

**2. Document design decisions:**
```
@decide "Send reset tokens via email" because "More secure than SMS, users already verified email"

@decide "Tokens expire after 1 hour" because "Balance security vs user convenience"
```

**3. Note technical details:**
```
@note "Use SendGrid for emails"
@note "Token format: JWT with 'reset' claim"
@note "Store reset tokens in Redis with 1hr TTL"
```

### Implementation Phase

**Track progress:**
```
@log "Created email template"
@log "Implemented token generation"
@log "Added /reset-password endpoint"
```

**Record patterns:**
```
pattern: "Email Sending Pattern"
```
Then explain the reusable pattern to your AI.

**Document code locations:**
```
@note "Password reset controller: controllers/auth/reset_controller.ex"
@note "Email template: templates/emails/password_reset.html"
```

### Testing Phase

**Track test results:**
```
@note "Tested: Gmail, Outlook, Yahoo - all working"
@bug "Hotmail: Emails going to spam"
```

### Completion

**Mark done:**
```
"Mark requirement 'Password reset' as complete"
```

**Document lessons:**
```
@lesson "Email Deliverability" "Always check DMARC/SPF/DKIM before sending to production. Most spam issues are DNS-related."
```

---

## 🐛 Bug Tracking Workflow

**Goal:** Systematically find and fix bugs

### When You Discover a Bug

**1. Log it:**
```
@bug "Login fails on Safari 16.2 - button click doesn't POST"
```

**2. Add context:**
```
@note "Bug only occurs on macOS Safari, not iOS Safari"
@note "Console shows: 'form.submit is not a function'"
```

**3. Flag as blocker if critical:**
```
@flag "Safari login blocking 30% of users (Safari analytics)"
```

### During Investigation

**Document findings:**
```
@note "Safari issue: Using form.submit() instead of HTMLFormElement.submit()"
@note "Polyfill breaks Safari's native form submission"
```

**Search for related issues:**
```
@search "Safari"
@search "form submit"
```

### When Fixed

**Document solution:**
```
@note "Fixed: Replaced form.submit() with requestSubmit() - works in all browsers"
```

**Resolve the blocker:**
```
"Resolve blocker <id>. Solution: Updated form submission method"
```

**Record the lesson:**
```
@lesson "Safari Form Submission" "Safari has stricter form API requirements. Use requestSubmit() instead of submit() for better compatibility."
```

---

## 📚 Learning/Research Workflow

**Goal:** Organize learning and reference materials

### Starting a Learning Project

**1. Create context:**
```
"Create new context: learning-nextjs"
```

**2. Set goals:**
```
@requirement "Complete Next.js tutorial" "Finish official Next.js tutorial and build sample blog"

@requirement "Deploy sample app" "Deploy working Next.js app to Vercel"
```

### During Learning

**Capture key concepts:**
```
@note "Next.js uses file-based routing: /pages/about.js → /about"

@note "getServerSideProps runs on server, getStaticProps at build time"

@note "API routes go in /pages/api directory"
```

**Track resources:**
```
@note "Tutorial: https://nextjs.org/learn"
@note "Docs: https://nextjs.org/docs"
@note "Useful article: Server components explained - url"
```

**Record what you built:**
```
@log "Built basic blog with markdown support"
@log "Added dynamic routing for blog posts"
@log "Deployed to Vercel successfully"
```

### Referencing Later

**Quick search:**
```
@search "routing"      # Find routing notes
@search "deploy"       # Find deployment info
@search "api"          # Find API notes
```

**See progress:**
```
@status                # Shows learning progress
```

---

## 👀 Code Review Workflow

**Goal:** Document reviews and track feedback

### Preparing for Review

**Document what changed:**
```
@log "Added user authentication system"
@note "Changes: auth controller, middleware, tests"
@note "PR #42: https://github.com/user/repo/pull/42"
```

### During Review

**Track feedback:**
```
@note "Review feedback: Add rate limiting to login endpoint"
@note "Review feedback: Use constant-time comparison for passwords"
```

**Record decisions:**
```
@decide "Use bcrypt with cost factor 12" because "Recommended by OWASP for 2024"
```

### After Review

**Document outcome:**
```
record_review: "Authentication PR #42"
status: "approved"  
summary: "Implemented bcrypt, added rate limiting, updated tests"
```

**Implemented changes:**
```
@note "Added express-rate-limit with 5 attempts/15min"
@note "Switched password comparison to crypto.timingSafeEqual"
```

---

## 🤝 Team Handoff Workflow

**Goal:** Smooth knowledge transfer between team members

### Handing Off Work

**1. Queue important info throughout the day:**
```
@note "Finished API endpoints, all tests passing"
@note "Database migration created but not run yet"
@note "Found potential issue with error handling - needs investigation"
```

**2. End session with comprehensive summary:**
```
@end "Completed REST API, created migrations. Error handling concerns in validation middleware - specifically need to handle async errors better. Tomorrow: run migrations and test error cases."
```

**3. Export context for teammate:
**
```
"Export current context as markdown"
```

Share the exported file With your teammate!

### Receiving a Handoff

**1. Import context (if new project):**
```
"Create context for project-X"
"Bind to current directory"
```

**2. Review handoff:**
```
@resume
```

**3. Search specific topics:**
```
@search "migration"    # Find database migration info
@search "error"        # Find error handling notes
```

**4. Ask questions (document answers):**
```
@note "Clarification from Alex: Async errors handled by express-async-errors package"
```

---

## 🗂️ Multiple Project Workflow

**Goal:** Manage several projects without confusion

### Project Switching

**Current project:**
```
@status           # See current project
```

**Switch project:**
```
"Switch to context: personal-blog"
```
Or just `cd` to that project directory and:
```
@start            # Auto-detects new context
```

### Quick Project Check-In

**See all projects:**
```
"List all my contexts"
```

**Check specific project:**
```
"What's the status of my blog project?"
@search "blog deployment"   # If in that context
```

### Cross-Project References

**Link related projects:**
```
"Link backend context to frontend context as 'depends-on'"
```

**See dependencies:**
```
@graph            # Visualize project relationships
```

### Project-Specific Notes

**Each project stays separate:**
```
# In project A
@note "Uses PostgreSQL"

# In project B  
@note "Uses MongoDB"

# Notes never mix!
```

---

## 💡 Pro Tips

### Tip 1: Use Tags Consistently

Create a tagging system:
```
@note "..." #backend #api #v2
@note "..." #frontend #ui #mobile
@note "..." #infra #deployment
```

Search by tag:
```
@search tag:backend
@search tag:deployment
```

### Tip 2: Queue Items as You Work

Don't wait until end of session:
```
@note "Finished X"     # Queues for handoff
@note "Started Y"      # Queues for handoff
@note "this"           # Quick capture
```

At `@end`, they're auto-included!

### Tip 3: Use Workflow Detection

Stuck? Ask:
```
@flow
```

Diwa suggests what to do based on your project state!

### Tip 4: Review Regularly

Weekly review:
```
@history           # See what changed this week
@status            # Project overview
```

Monthly review:
```
@search tag:decision    # All decisions
@search tag:lesson      # All lessons learned
```

### Tip 5: Document Decisions Immediately

Right when you decide:
```
@decide "..." because "..."
```

Don't wait! You'll forget the reasoning.

---

## 🎯 Workflow Templates

### Bug Fix Template

```
1. Log bug: @bug "description"
2. Investigate: @note "findings"
3. Fix: @log "implemented fix"
4. Test: @note "test results"
5. Lesson: @lesson "what I learned"
6. Close: resolve blocker
```

### Feature Template

```
1. Requirements: @requirement "feature" "details"
2. Design: @decide choices with rationale
3. Implement: @log progress, @note tech details
4. Test: @note test results
5. Deploy: record_deployment
6. Complete: mark requirement done
```

### Learning Template

```
1. Goal: @requirement "learn X"
2. Resources: @note "tutorial links"
3. Notes: @note "key concepts"
4. Practice: @log "what I built"
5. Review: @search to reinforce
```

---

## 🆘 When Things Go Wrong

### "I forgot to end my session"

No problem!
```
@start        # Starts new session
"Check what I was working on yesterday"
```

### "I can't remember what I called something"

Try different searches:
```
@search "partial word"
@search tag:type
@history      # Browse recent activity
```

### "I stored wrong information"

Update it:
```
"Update memory XYZ to correct info"
```

### "I'm in the wrong context"

Switch:
```
@start        # Auto-detects correct context
# or
"Switch to context: project-name"
```

---

## 📚 Next Steps

Want to learn more?

- **Understand core ideas**: [Core Concepts](./concepts.md)
- **See all tools**: [Tools Reference](./TOOLS.md)
- **Get help**: [Troubleshooting](./TROUBLESHOOTING.md)

---

**The key to effective Diwa use:**
1. **Use it regularly** - Make it a habit
2. **Store liberally** - When in doubt, store it!
3. **Search often** - Your knowledge grows over time
4. **Trust the system** - Diwa helps you find things

Happy workflow! 🚀

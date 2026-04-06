---
name: reflect
description: >
  Self-reflection after work sessions. Generates structured reflections or reviews pending ones.
  Use when the user runs /reflect or /reflect review. Also use when the user says
  "let's reflect", "what did we learn", "session learnings", "write a reflection".
user-invocable: true
tools: Read, Edit, Write, Glob, AskUserQuestion
---

# Reflect

Structured self-reflection that compounds learning into project-specific instructions.

## Mode Detection

- No arguments or `/reflect` → **Generate mode**
- `/reflect review` → **Review mode**

---

## Generate Mode

Reflect on the current conversation and produce a structured entry.

### Step 1: Gather Context

Review the conversation for:
- Tool calls that failed or required multiple attempts
- Decisions made and their reasoning
- Errors encountered and how they were resolved
- Patterns that emerged during the work
- Assumptions that turned out to be wrong

### Step 2: Write the Reflection Entry

Determine the current branch and date:

```bash
git branch --show-current 2>/dev/null || echo "unknown"
date +%Y-%m-%d
```

Produce a reflection with **exactly four categories**. Each category has 1-3 items max. Every item must be specific and actionable — no generic platitudes like "always test your code" or "read documentation carefully."

**Bad example:** "Testing is important"
**Good example:** "The `stripe.webhooks.constructEvent` function throws if the raw body is parsed as JSON first — always pass the raw Buffer"

Format each item as: `- [PENDING] <specific, actionable observation>`

Append to `.claude/REFLECTION.md` using this format:

```
## YYYY-MM-DD — branch: <branch> — <one-line summary of work>

### Surprises
- [PENDING] <item>

### Patterns
- [PENDING] <item>

### Prompt improvements
- [PENDING] <item>

### Mistakes
- [PENDING] <item>
```

If the file doesn't exist yet, create it with a `# Reflections` header first.

If a category has nothing worth noting, write `- [PENDING] Nothing notable this session` — do not omit the category.

### Step 3: Add @REFLECTION.md to CLAUDE.md

Check if the project has `.claude/CLAUDE.md`:

```bash
test -f .claude/CLAUDE.md && echo "exists" || echo "missing"
```

If it exists, check if `@REFLECTION.md` is already referenced. If not, add it:

```
@REFLECTION.md
```

If `.claude/CLAUDE.md` does not exist, inform the user:
> "Note: No `.claude/CLAUDE.md` found in this project. When you create one, add `@REFLECTION.md` to it so reflections are loaded as context."

### Step 4: Confirm

Show the user the reflection entry that was written. Done.

---

## Review Mode

Walk through pending reflections and apply approved ones to CLAUDE.md.

### Step 1: Find Pending Entries

Read `.claude/REFLECTION.md` and find all lines matching `- [PENDING]`.

If none found, report "No pending reflections to review." and stop.

### Step 2: Present Each Entry

For each `[PENDING]` entry, present it to the user with these options:
- **Approve** — will be rewritten as a directive and added to CLAUDE.md
- **Reject** — will be marked [REJECTED] and skipped
- **Edit** — user provides revised text, then approve

Present ONE entry at a time. Wait for the user's response before proceeding to the next.

### Step 3: Apply Approved Entries

For each approved entry:

1. Change `[PENDING]` to `[APPROVED]` in `.claude/REFLECTION.md`
2. Rewrite the entry into directive form — a concise instruction, not a reflection. Examples:
   - Reflection: "The OAuth library silently swallows 403 errors instead of throwing"
   - Directive: "Always wrap OAuth library callbacks in try/catch — it silently swallows 403 errors"
3. Append the directive to `.claude/CLAUDE.md` under a `## Learnings` section. Create the section if it doesn't exist.

For each rejected entry:

1. Change `[PENDING]` to `[REJECTED]` in `.claude/REFLECTION.md`

### Step 4: Summary

Report: "Review complete: N approved, N rejected, N remaining."

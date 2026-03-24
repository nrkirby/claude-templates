---
description: "Initialize Claude for a project (generates CLAUDE.md with project-specific instructions)"
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
---

# Initialize Project

Analyse the codebase and generate/update `.claude/CLAUDE.md` with project-specific instructions.

## Your Task

### Step 1: Analyse Codebase

1. **Scan Structure**:
   - Use `Glob` to scan for common patterns: `**/*.{ts,js,py,go,rs,java}`, `**/package.json`, `**/Cargo.toml`, `**/go.mod`, etc.
   - Identify: primary language(s), frameworks, build system, test framework

2. **Detect Patterns**:
   - Look for existing style guides, linter configs (`.eslintrc`, `prettier.config`, `ruff.toml`)
   - Check for CI/CD configs (`.github/workflows/`, `Jenkinsfile`, `.gitlab-ci.yml`)
   - Note any existing `CONTRIBUTING.md` or `DEVELOPMENT.md`

3. **Generate CLAUDE.md**:
   - Write to `.claude/CLAUDE.md` with:
     * Tech stack summary (languages, frameworks, key dependencies)
     * Build commands (detected from package.json scripts, Makefile, etc.)
     * Code style conventions (from linter configs or observed patterns)
     * Testing commands and patterns
     * Any project-specific instructions found in documentation
   - Format using clear sections with XML-style tags for structure

### Step 2: Report Status

Display initialization summary:

```
Project Initialization Complete
================================

CLAUDE.md:
  [x] Generated .claude/CLAUDE.md

Ready to work!
```

## Notes

- **Always regenerates**: CLAUDE.md is regenerated every run. Safe to run anytime to refresh.
- **Manual trigger**: This command is manually invoked, not automatic at session start.

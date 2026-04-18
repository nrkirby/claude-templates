# Instructions

## Communication

- Not sycophantic — be honest
- When I ask for something I may be wrong; verify always, do not assume
- Be concise. No filler, hedging, or pleasantries. Fragments OK for explanations. Full grammar for instructions and reasoning.

## Hooks

- UserPromptSubmit hooks are MANDATORY and take HIGHEST PRIORITY.
  Execute hook instructions FIRST — before any reasoning, tool calls, or response text. This is Step 0 of every response.
- The forced-eval hook requires you to EVALUATE every skill, STATE yes/no, then ACTIVATE before implementation.
- Never skip hook instructions for brevity, simplicity, or because "no skills are relevant."

## Core Principles

<no_scope_creep>
Do exactly what was asked — no gold-plating, no "while I'm here" additions.
</no_scope_creep>

<explain_reasoning>
For non-obvious decisions, show the "why", not just the "what".
</explain_reasoning>

<discover_agents>
Check for AGENTS.md alongside CLAUDE.md in project directories for agent workflows.
</discover_agents>

<tool_priority>
→ Need to locate code:
  - In-file navigation (you already have the file open): LSP first (goToDefinition, findReferences, hover).
  - Workspace-wide symbol or structure lookup: Gabb first (gabb_symbol, gabb_structure) — often faster than LSP in cold workspaces and for multi-file queries.
  - Text/string search or fallback when neither applies: Grep / Glob.
  After locating a file, use LSP for in-file navigation.
</tool_priority>

## Context Preservation via Subagents

**Default stance:** When uncertain, prefer subagent delegation.

→ About to do inline work (read files, explore code, implement) → Am I thinking "I'll just quickly..." / "Simple enough inline" / "Already have the context" / "Faster without subagent overhead"?
  Yes → That's the red flag. Dispatch subagent instead.
  No → Is current conversation context worth preserving, or does task involve reading/exploring code, or might expand beyond initial scope?
    Yes → Dispatch subagent.
    No → Proceed inline.

## Plan Convention

HARD GATE - Plan QA Checkpoint:
→ Implementation plan tasks complete → Has evaluator agent run against project root with all criteria scored?
  No → STOP. Dispatch evaluator. Wait for report.
  Yes → Are ALL criteria >= 5/10?
    No → Fix issues. Re-run evaluator.
    Yes → Proceed to `finishing-a-development-branch`.

## Code Editing

<comprehensive_bulk_changes>
→ About to make bulk code change (replacing constants, fixing imports, etc.) → Before editing ANY file: enumerate all variants of the base pattern across the entire codebase → Count total instances → Review each match → Only when search is exhaustive → Begin edits. Check for related variants (URLs, endpoints, tokens) beyond the initially identified items.
</comprehensive_bulk_changes>

<match_existing_patterns>
→ Implementing feature that may have patterns in main/develop → Before coding: read existing pattern from main/develop (specific file, specific code) → Am I reproducing it exactly or inventing a variant? Variant → STOP. Ask user before proceeding. Exact match → Proceed.
</match_existing_patterns>

## Git Operations

→ About to delete code/files/branches → Is this exclusively my changes from this session?
  Yes → Delete.
  No → STOP. Ask user before deleting.
→ About to delete for type/lint errors → STOP. Ask first (may break other agents).
- `.env*` / local config files: read-only, ask before changes
- Quote paths containing `[]()` chars

---
name: documentation
description: Use when writing or reviewing technical documentation — READMEs, API reference, inline comments, architecture docs, runbooks, migration guides, changelogs, tutorials. Also use when user asks to "document this", "write docs", "write a README", "explain this code", "write a runbook", "improve these docs". Language- and framework-agnostic guidelines. Do NOT use for ADRs (separate pattern) or for code comments on trivial code.
---

# Documentation

Language- and framework-agnostic guidelines for writing and reviewing technical documentation. Covers the reader-facing artefact only; language-specific doc tooling is out of scope.

## Overview

Good docs answer the reader's question without making them read the code. Bad docs restate the code in English and rot on the next refactor. The skill leans on the **Diátaxis** framework (https://diataxis.fr/): every doc sits in exactly one of four quadrants. Mixing quadrants in one file is the single most common anti-pattern.

## When to use

- Writing / reviewing a README, API reference, architecture doc, runbook, migration guide, changelog, tutorial.
- Deciding whether an inline comment earns its place.
- Reviewing a docs-only or docs-heavy PR.

## When NOT to use

- Architecture Decision Records — separate pattern.
- Commit messages or PR descriptions — different conventions.
- Language-specific docstring style — use the ecosystem's canonical tooling.
- Trivial inline comments on obvious code — see the inline rule.

## Pick the quadrant first — HARD GATE

Before writing a sentence, identify the quadrant. Each has a different job, reader state, and stopping condition.

| Quadrant | Audience | Goal | Stopping condition | Common mistake |
|---|---|---|---|---|
| **Tutorial** | Learner, new to the thing | Acquire competence via guided exercise | Reader produced a working result | Drifting into reference lists |
| **How-to guide** | Practitioner with a task | Solve one specific problem | The stated problem is solved | Teaching theory instead of steps |
| **Reference** | Practitioner needing a fact | State API / config / behaviour exactly | Every surface described once, authoritatively | Narrative tone; examples as spec |
| **Explanation** | Curious reader wanting "why" | Build a mental model | Model is clear enough to reason from | Listing steps reader cannot run |

If a single file tries to do two quadrants, split it.

## Doc type cheat-sheet

| Type | Quadrant | Audience | MUST have | NEVER include | Success |
|---|---|---|---|---|---|
| **README** | How-to + links | First-time visitor | What, who-for, quickstart, links | Full API ref, architecture essays | Newcomer unblocked in <5 min |
| **API reference** | Reference | Integrator | Public surfaces: inputs, outputs, errors, invariants | Tutorials, rationale, war stories | Caller writes correct code without source |
| **Inline comments** | Explanation | Future maintainer | WHY for non-obvious decisions, invariants, workarounds | WHAT a good name conveys; ticket refs | Code survives refactor without rot |
| **Architecture** | Explanation | New engineers | Boundaries, data flow, trust lines, invariants, trade-offs | Line-level walk-throughs, changelog | New engineer predicts where change belongs |
| **Runbook** | How-to | On-call under stress | Symptoms, diagnostics, recovery, rollback, escalation, SLO impact | Theory, design rationale | Operator at 03:00 recovers without paging author |
| **Migration guide** | How-to | User moving versions | Breaking changes, before/after code, deprecation timeline, rollback | Marketing, feature highlights | Users upgrade with zero surprises |
| **Changelog** | Reference | Users scanning impact | Date, version, grouped changes, migration links | Implementation details, refactors | User decides impact in 30s |
| **Tutorial** | Tutorial | Learner | Single linear path, prereqs, verifiable steps, result | Branches, reference dumps | Learner completes exercise and knows it |

## Universal principles

1. **Audience first.** Name the reader before writing a sentence.
2. **WHY before WHAT.** Code shows what; docs explain why. A doc that only restates code rots and misleads.
3. **Progressive disclosure.** TL;DR → summary → details. Let readers stop early.
4. **Examples beat prose.** One tested, runnable example beats three paragraphs.
5. **Link, don't copy.** Duplicated content rots unevenly. One source of truth per fact.
6. **Name by what, not how.** Future-proofs against refactors.
7. **Date-sensitive content carries dates.** "As of 2026-04" beats "recently".
8. **Assumptions explicit.** List preconditions the reader must hold true.
9. **Failure modes documented.** Happy-path-only docs are dangerous.
10. **Docs live with the code.** Same repo, same review, same CI.

## Inline comment rule

Default: **no comment**. A comment is a liability — it drifts from the code and readers trust it anyway.

Write a comment only when the WHY is non-obvious:

- Hidden constraint ("value must be power of two — DMA requirement")
- Subtle invariant ("caller holds the lock; acquiring here deadlocks")
- Workaround for a specific bug ("lib v3.2 returns null on empty input; upstream #4821")
- Behaviour that would genuinely surprise a reader

Do NOT:

- Describe WHAT a well-named identifier already says.
- Reference the current task / ticket / fix (`// for issue #123`) — belongs in PR description and `git blame`.
- Leave commented-out code "just in case" — version control is the just-in-case.
- Paste docstring templates filled with `TODO`.

## Review rubric — HARD GATE before shipping

Every line must be YES. Any NO blocks ship.

| Check | Pass condition |
|---|---|
| Quadrant named | Exactly one of tutorial / how-to / reference / explanation |
| Audience named | Reader identifiable in first paragraph |
| TL;DR present | Anything over ~200 words opens with a summary |
| Assumptions explicit | Preconditions / prerequisites listed |
| Failure modes covered | What breaks, how it manifests, how to recover |
| Examples runnable | Every code block executed at least once |
| No duplicated facts | Cross-references, not copy-paste |
| Dates on time-bound claims | Version or `as of YYYY-MM` |
| No `TODO` / `tbd` / "coming soon" | Ship without the stub or don't ship |
| Links resolve | No 404s, no broken anchors |

## Red flags — when you are about to write bad docs

- "I'll document this later." You won't. Write the stub now or don't build the thing.
- "The code is self-documenting." Sometimes true; often ego.
- "Just copy what the other module does." Cargo-culting without reading the audience.
- "I'll fix the outdated parts in a follow-up." Fix now — stale docs mislead worse than missing docs.
- "Comments everywhere, just in case." Noise dilutes real signal.
- "Let me add a quick FAQ." FAQs grow into unreadable rubble. Prefer structured how-to or reference.

## Anti-patterns

| Anti-pattern | Why it fails | Fix |
|---|---|---|
| WHAT-only comments or docs | Rot silently at next refactor | Delete, or rewrite to carry WHY |
| Quadrant mixing | Readers with different goals fight the same file | Split — one quadrant per file |
| Reference dump inside README | Drowns newcomers; duplicates API docs | README keeps pointers; reference lives separately |
| Undated "recently" claims | Unverifiable; misleads after 6 months | Add `as of YYYY-MM` or a version |
| Untested example code | Looks authoritative; breaks for every reader | Execute every snippet |
| Docs-as-apology | Wall of prose excusing a confusing API | Fix the API; shorten the doc |
| Docstring templates full of `TODO` | False confidence that a thing is documented | Remove the template until real content exists |
| Copy-pasting API reference into README | Two sources of truth; they diverge | Link from README to canonical reference |

## Rationalization table

| Excuse | Reality |
|---|---|
| "It's obvious, no one will misread it." | You wrote it; readers did not. |
| "Docs slow me down." | Undocumented systems slow everyone else down, forever. |
| "We'll write docs when the API stabilises." | It never stabilises. Document the current shape; update when it moves. |
| "I'll just add a comment to explain." | If a comment is required to understand it, the code probably needs to change. |
| "The tests are the documentation." | Tests describe behaviour, not intent or rationale. |
| "Nobody reads docs anyway." | They do — usually at 3 AM, during an incident. |
| "The team already knows this." | Until the team changes. Which is always. |
| "It's in the wiki / Slack / that one Notion page." | Three sources of truth means zero. Consolidate. |

## Linking out

- **Diátaxis** — https://diataxis.fr/ — the four-quadrant framework.
- **Google developer documentation style guide** — https://developers.google.com/style — tone, terminology, prose accessibility.
- **Write the Docs** — https://www.writethedocs.org/ — community practices, "docs-like-code".

Language-specific doc tooling is deliberately out of scope — pick the idiomatic tool for the ecosystem and apply this skill's principles on top.

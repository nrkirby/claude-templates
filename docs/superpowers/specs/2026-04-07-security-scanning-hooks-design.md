# Security Scanning Hooks Design

**Date:** 2026-04-07
**Status:** Approved

## Problem

AI coding agents introduce security vulnerabilities at a high rate — DryRun Security's 2026 report found 87% of AI-generated PRs contained at least one vulnerability across Claude Code, OpenAI Codex, and Google Gemini. The claude-templates project has manual security skills (threat-modeling, dast-scan, security-review) and a PreToolUse warning hook (Security Guidance), but no automated scanning that runs on every code change.

The goal is to add cheap, fast, automated security scanning — similar to how lint-guard enforces linting via a Stop hook, but for security.

## Approach: Plugin + Tool

Use the official Semgrep Claude Code plugin for SAST scanning (PostToolUse on every Edit/Write) and Gitleaks as a global git pre-commit hook for secret detection at commit time.

### Why this split

- **Semgrep plugin** is maintained by Semgrep, already implements PostToolUse hooks, bundles SAST + Supply Chain + Secrets scanning, and uses the free OSS CLI with community rules (no paid account required).
- **Gitleaks** is the fastest secret scanner (sub-second on staged files), purpose-built for git hooks, and complements Semgrep Secrets as defense-in-depth.
- This avoids building custom Claude Code hooks — the plugin handles the complex part.

## Components

### 1. `tools/semgrep.sh`

Installs the Semgrep OSS CLI via Homebrew. Prerequisite for the Semgrep plugin.

Functions (following existing tools/ pattern):
- `install_semgrep()` — check if installed, `brew install semgrep`, verify version
- `update_semgrep()` — `brew upgrade semgrep`
- `uninstall_semgrep()` — `brew uninstall semgrep`

No MCP registration, no hooks — the plugin handles those.

### 2. `tools/gitleaks.sh`

Installs Gitleaks via Homebrew and sets up a global git pre-commit hook.

`install_gitleaks()`:
1. `brew install gitleaks`, verify installation
2. Create `~/.git-hooks/` directory if it doesn't exist
3. Set `git config --global core.hooksPath ~/.git-hooks` only if `core.hooksPath` is not already configured
4. Create `~/.git-hooks/pre-commit` only if no existing pre-commit hook exists
5. The hook script:
   - Skippable via `SKIP_GITLEAKS=1` environment variable
   - Gracefully exits if gitleaks binary not found
   - Runs `gitleaks git --pre-commit --staged --redact -v`
   - Chains to repo-local hooks via `$(git rev-parse --git-dir)/hooks/pre-commit` fallback
6. If a pre-commit hook already exists, add a warning suggesting manual integration

`update_gitleaks()`:
- `brew upgrade gitleaks`

`uninstall_gitleaks()`:
- `brew uninstall gitleaks`
- Remove the pre-commit hook file only if it contains only the gitleaks hook (no other content)
- If the file has other content, warn the user to remove the gitleaks section manually

### 3. `config.sh` changes

```bash
readonly TOOLS=(
    # ... existing entries ...
    "semgrep"
    "gitleaks"
)

readonly MARKETPLACES=(
    "pvillega/claude-templates:claude-templates"
    "semgrep/mcp-marketplace:semgrep"
)

readonly PLUGINS=(
    # ... existing entries ...
    "semgrep-plugin@semgrep"
)
```

### 4. README updates

Document in the project README:
- What Semgrep plugin provides (SAST + Supply Chain + Secrets, PostToolUse scanning)
- That `/semgrep-plugin:setup-semgrep-plugin` is optional (enables pro rules with a free Semgrep account)
- What Gitleaks provides (secret detection at commit time)
- The `SKIP_GITLEAKS=1` escape hatch
- Note about `core.hooksPath` overriding per-repo `.git/hooks/` (mitigated by chain-through in the hook script)

## What's NOT in scope

- No custom Claude Code hooks (Semgrep plugin provides PostToolUse)
- No new Claude Code skills
- No changes to existing security skills (threat-modeling, dast-scan, security-review, find-bugs)
- No dependency vulnerability scanning hooks (covered by Semgrep Supply Chain in the plugin)
- No changes to the existing Security Guidance PreToolUse hook

## Security coverage after implementation

| Layer | Tool | Trigger | What it catches |
|-------|------|---------|-----------------|
| PreToolUse warning | Security Guidance plugin | Before Edit/Write | OWASP pattern warnings |
| PostToolUse scan | Semgrep plugin | After Edit/Write | SAST vulnerabilities, dependency CVEs, hardcoded secrets |
| Git pre-commit | Gitleaks | On `git commit` | Leaked secrets (defense-in-depth) |
| Manual skills | threat-modeling, dast-scan, security-review, find-bugs | On demand | Design-level threats, runtime vulnerabilities, deep code review |

## References

- [DryRun Security Report — AI Coding Agent Security](https://www.helpnetsecurity.com/2026/03/13/claude-code-openai-codex-google-gemini-ai-coding-agent-security/)
- [Semgrep MCP Marketplace](https://github.com/semgrep/mcp-marketplace)
- [Semgrep Plugin Docs](https://semgrep.dev/docs/mcp)
- [Gitleaks GitHub](https://github.com/gitleaks/gitleaks)
- [Trail of Bits claude-code-config](https://github.com/trailofbits/claude-code-config) (evaluated, not used — too heavy)

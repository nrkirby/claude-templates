# Claude Templates

> **WARNING: This project is designed for use in sandboxed environments only.**
> It uses `--dangerously-skip-permissions` mode and relies on Claude Code's
> sandbox to restrict filesystem, network, and command access. Do NOT use this
> configuration on machines with production credentials, sensitive data, or
> access to production systems. See [About Safety](#about-safety) for details.

A plugin marketplace providing tested skills, commands, agents, and MCP server configurations for Claude Code. Designed for YOLO mode (`--dangerously-skip-permissions`) with sandbox safety guards.

## Quick Start

### Option A: Full install (recommended)

Clones the repo and runs the install script, which handles everything: marketplace registration, plugin installation, sandbox settings, and npm dependencies.

```bash
git clone https://github.com/pvillega/claude-templates.git
cd claude-templates
./install.sh
```

### Option B: Plugin only (manual)

If you only want the plugin (skills, commands, agents, MCP servers) without the sandbox settings and npm packages:

```bash
# Add the marketplace
claude plugin marketplace add pvillega/claude-templates

# Install the ct plugin
claude plugin install ct@claude-templates

# Also install superpowers and playwright-skill (recommended)
claude plugin marketplace add obra/superpowers-marketplace
claude plugin install superpowers@superpowers-marketplace
claude plugin marketplace add lackeyjb/playwright-skill
claude plugin install playwright-skill@playwright-skill
```

**Note:** Option B does not configure sandbox settings or install global npm packages (jscpd). You will need to set those up separately if desired.

### After install

```bash
# Add this alias to your shell config (~/.bashrc or ~/.zshrc)
alias cl='claude --dangerously-skip-permissions'

# In your project, initialise
cl
/ct:init
```

## About Safety

Using agents without restrictions on tools poses some dangers. It could impact files outside your workspace, potentially damaging your system. Or it can [exfiltrate](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/) data.

As a consequence, using Claude Code from your local environment by itself is risky. Currently, there are three popular ways of using Claude Code to combat these issues:

- [DevContainers](https://containers.dev): these sandbox the codebase and agent in a Docker container. This safeguards your computer if you do not use privileged mode or mount external volumes. Restricting traffic can be more complicated, depending on your needs. They can be used in [GitHub Codespaces](https://github.com/features/codespaces) for extra isolation. The downside is that you need to re-authenticate on each new container, and they take a long time to start. Not ideal if you want to use many branches in parallel.
- [Claude Code for Web](https://claude.com/blog/claude-code-on-the-web): it provides an isolated sandbox environment to run your code, and reads your local `.claude` folder. It doesn't support `plugins` and doesn't work well with `mcp`, unless you have them deployed remotely via some gateway.
- [Claude Code for Desktop](https://code.claude.com/docs/en/desktop): it provides an isolated sandbox environment to run your code, using a worktree to isolate changes from the code, and it runs on your local machine. This means that it reads your `~/.claude` folder and settings.
- A [Sandbox runtime](https://github.com/anthropic-experimental/sandbox-runtime): like the linked one, this is an experimental tool provided by Anthropic. It provides the advantages of using a container, without the drawbacks. Unfortunately, this tool is not fully compatible with Claude as it stands, because it denies file operations to `/dev/ttys*`, breaking `raw mode` necessary for Claude Code.
- Use [Claude Sandbox](https://code.claude.com/docs/en/sandboxing), which is a more limited version of the [Sandbox runtime](https://github.com/anthropic-experimental/sandbox-runtime), but it is provided by Claude itself.

This project uses the `Claude Sandbox` approach. Ideally, we could use the full sandbox but, as mentioned, it is not compatible with Claude Code. The advantage of doing this is that it also seamlessly works for [Claude Code for Desktop](https://code.claude.com/docs/en/desktop), as they will share configuration.

Please note this approach mitigates some risks, but not all. `Claude Sandbox` doesn't restrict domains by whitelisting, unlike some of the alternatives. Use of Docker, MCPs, and third-party libraries means there is a risk of data exfiltration if they are compromised. Claude can still read your environment variables and share keys.

This means that the sandbox will protect you from some issues (a process reading your SSH configuration or AWS credentials on disk), but good practices are still necessary: do not use production credentials or data in your development environments. Do not use unknown or unsafe Docker images. Do not run random MCP servers.

## Setup

The [install.sh](install.sh) script installs the Claude Code plugin, sandbox settings, and marketplace configuration. Run it from the repository root:

```bash
./install.sh
```

Use `--clean` for a fresh install when you want to remove stale configuration that might not be properly overridden. The `--dry-run` flag lets you preview what would be deleted before committing.

To reverse the installation, run [uninstall.sh](uninstall.sh).

After installation, add the `cl` alias to your shell config (`~/.bashrc` or `~/.zshrc`):

```bash
alias cl='claude --dangerously-skip-permissions'
```

### API Keys

Some MCP servers (Perplexity, Tavily) require API keys. You can configure these via:

- **mise** (recommended): Copy `mise.toml.example` to `mise.toml` in your project and fill in your keys. See [mise.jdx.dev](https://mise.jdx.dev/getting-started.html) for installation.
- **Shell exports**: Add `export PERPLEXITY_API_KEY=...` and `export TAVILY_API_KEY=...` to your shell profile.

MCP servers that require missing API keys will produce errors. If you do not plan to use them, this is safe to ignore.

## In a Project

When working with Claude in a project:

1. Start Claude with `cl` (the alias configured above).
2. On first use, run `/ct:init` to generate a project-specific `CLAUDE.md` with tech stack detection, code style conventions, and suggested build commands.
3. See [Workflows.md](./Workflows.md) for detailed guidance on using commands, agents, and skills effectively.

**Note:** The project instructions assume a `buildAll.sh` script exists that runs all relevant build steps (build, lint, test, formatting, etc.). Claude uses this script to verify changes work.

## Contents

The repository has the following files:

- **[install.sh](install.sh)** - Setup script (marketplace, plugin, sandbox settings)
- **[uninstall.sh](uninstall.sh)** - Reverses install actions
- **[plugins/ct/](plugins/ct/)** - The Claude Code plugin (skills, commands, agents, MCP)
- **[templates/CLAUDE.md](templates/CLAUDE.md)** - Template project instructions
- **[sandbox-settings.json](sandbox-settings.json)** - Sandbox security configuration
- **[mise.toml.example](mise.toml.example)** - Environment variable template for API keys
- **[Workflows.md](Workflows.md)** - Recommended workflows

### Plugin Contents

The `ct` plugin provides:

- **Skills (12):** architecture-discipline, backend-reliability-enforcer, confidence-check, deployment-automation-enforcer, duplicate-code-detector, edge-case-discovery, frontend-production-quality, incremental-refactoring, meta-agent, performance-optimization, security-compliance-audit, threat-modeling
- **Commands:** /ct:init, /ct:commit, /ct:research, /ct:discover-aliases, /ct:grammar-check, /ct:repo-index, and meta commands (skills-check, test-agent, test-all-skills, test-skill)
- **Agents:** deep-research, pr-review-assistant, refactor-scan, repo-index
- **MCP Servers:** Context7, Playwright, Perplexity, Tavily, shadcn

## Acknowledgements

This repository was inspired by and incorporates patterns from:

- **[SuperClaude Framework](https://github.com/SuperClaude-Org/SuperClaude_Framework)**: A comprehensive framework for enhanced Claude Code capabilities
- **[Superpowers](https://github.com/obra/superpowers/)**: A comprehensive skills library of proven techniques, patterns, and workflows for AI coding assistants
- **[ClaudeLog](https://claudelog.com)**: Community-driven best practices and patterns

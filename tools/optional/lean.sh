#!/usr/bin/env bash

# Opt-in installer for Lean 4 tooling integration with Claude Code.
#
# Standalone: runnable via `bash tools/optional/lean.sh` or `./tools/optional/lean.sh`.
# Does NOT source install.sh internals — defines its own minimal helpers.
#
# What it does (each section is idempotent):
#   A. Prereq gate (uv, rg, jq, claude)
#   B. Install `lean-lsp-mcp` at user scope via `claude mcp add`
#   C. Register `cameronfreer/lean4-skills` marketplace in ~/.claude/settings.json
#   D. Enable the `lean4@cameronfreer` plugin
#   E. Install PostToolUse `lake build` hook script + registration
#   F. Print final summary
#
# Flags / env:
#   --dry-run    Echo "DRY-RUN: <would do X>" for every mutating action. No changes.
#   DRY_RUN=1    Same as --dry-run.

set -euo pipefail

# ------------------------------------------------------------------------------
# Minimal helpers (independent of install.sh)
# ------------------------------------------------------------------------------

_err() {
    echo "ERROR: $*" >&2
}

_warn() {
    echo "WARN:  $*" >&2
}

_info() {
    echo "$*"
}

# ------------------------------------------------------------------------------
# Flag parsing
# ------------------------------------------------------------------------------

DRY_RUN="${DRY_RUN:-0}"
for arg in "$@"; do
    case "$arg" in
        --dry-run)
            DRY_RUN=1
            ;;
        -h|--help)
            cat <<USAGE
Usage: $0 [--dry-run]

Installs Lean 4 tooling integration for Claude Code:
  - lean-lsp-mcp (MCP server, user scope)
  - cameronfreer/lean4-skills marketplace registration
  - lean4@cameronfreer plugin enablement
  - PostToolUse lake-build-on-edit hook

Environment:
  DRY_RUN=1     same as --dry-run
USAGE
            exit 0
            ;;
        *)
            _err "unknown argument: $arg"
            exit 1
            ;;
    esac
done

if [ "$DRY_RUN" = "1" ]; then
    _info "== DRY-RUN mode: no system state will be modified =="
fi

# Helper: perform an action, or echo the DRY-RUN equivalent.
# Usage: _do "description" -- cmd args...
_do() {
    local desc="$1"; shift
    # Expect literal '--' separator for readability
    if [ "${1:-}" = "--" ]; then shift; fi
    if [ "$DRY_RUN" = "1" ]; then
        echo "DRY-RUN: would $desc"
        return 0
    fi
    "$@"
}

# ------------------------------------------------------------------------------
# Section A — prereq gate
# ------------------------------------------------------------------------------

_info ""
_info "[A] Checking prerequisites..."

_missing=()
for cmd in uv rg jq claude; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        _missing+=("$cmd")
    fi
done

if [ "${#_missing[@]}" -gt 0 ]; then
    _err "missing required command(s): ${_missing[*]}"
    _err "install hints:"
    _err "  uv     -> brew install uv   (or: curl -LsSf https://astral.sh/uv/install.sh | sh)"
    _err "  rg     -> brew install ripgrep"
    _err "  jq     -> brew install jq"
    _err "  claude -> https://docs.anthropic.com/en/docs/claude-code"
    exit 2
fi
_info "  uv, rg, jq, claude: OK"

# ------------------------------------------------------------------------------
# Shared settings-file helpers (used by C/D/E)
# ------------------------------------------------------------------------------

SETTINGS_FILE="$HOME/.claude/settings.json"

_ensure_settings_file() {
    if [ "$DRY_RUN" = "1" ]; then
        echo "DRY-RUN: would ensure $SETTINGS_FILE exists (mkdir -p, write '{}' if missing)"
        return 0
    fi
    mkdir -p "$HOME/.claude"
    if [ ! -f "$SETTINGS_FILE" ]; then
        echo '{}' > "$SETTINGS_FILE"
    fi
    if ! jq empty "$SETTINGS_FILE" 2>/dev/null; then
        _err "$SETTINGS_FILE is not valid JSON; aborting to avoid clobber"
        exit 3
    fi
}

# jq-merge helper: atomic write via tmp+mv.
# Args: <jq program> [jq args...]
_jq_inplace() {
    local prog="$1"; shift
    if [ "$DRY_RUN" = "1" ]; then
        echo "DRY-RUN: would jq-update $SETTINGS_FILE with program: $prog"
        return 0
    fi
    local tmp="${SETTINGS_FILE}.tmp"
    if ! jq "$@" "$prog" "$SETTINGS_FILE" > "$tmp"; then
        rm -f "$tmp"
        _err "jq update failed for program: $prog"
        return 1
    fi
    mv "$tmp" "$SETTINGS_FILE"
}

# ------------------------------------------------------------------------------
# Section B — install lean-lsp-mcp at user scope
# ------------------------------------------------------------------------------

_info ""
_info "[B] lean-lsp-mcp (user scope)..."

STATUS_MCP="unknown"
if claude mcp list 2>/dev/null | grep -qE '^lean-lsp(\b|:|[[:space:]])'; then
    _info "  lean-lsp MCP already installed, skipping"
    STATUS_MCP="already present"
else
    if _do "run: claude mcp add -s user lean-lsp -- uvx lean-lsp-mcp" -- \
            claude mcp add -s user lean-lsp -- uvx lean-lsp-mcp; then
        if [ "$DRY_RUN" = "1" ]; then
            STATUS_MCP="dry-run"
        else
            if claude mcp list 2>/dev/null | grep -qE '^lean-lsp(\b|:|[[:space:]])'; then
                STATUS_MCP="installed"
                _info "  lean-lsp MCP installed"
            else
                _warn "claude mcp add appeared to succeed but lean-lsp is not in 'claude mcp list'"
                STATUS_MCP="install attempted (verification failed)"
            fi
        fi
    else
        _warn "failed to add lean-lsp MCP"
        STATUS_MCP="failed"
    fi
fi

# ------------------------------------------------------------------------------
# Section C — register cameronfreer/lean4-skills marketplace
# ------------------------------------------------------------------------------

_info ""
_info "[C] cameronfreer/lean4-skills marketplace registration..."

STATUS_MARKET="unknown"
_ensure_settings_file

# Detect existing, correctly-configured entry.
_already_registered=0
if [ "$DRY_RUN" != "1" ] && [ -f "$SETTINGS_FILE" ]; then
    _existing_repo=$(jq -r '.extraKnownMarketplaces.cameronfreer.source.repo // ""' "$SETTINGS_FILE" 2>/dev/null || echo "")
    if [ "$_existing_repo" = "cameronfreer/lean4-skills" ]; then
        _already_registered=1
    fi
fi

if [ "$_already_registered" = "1" ]; then
    _info "  marketplace already registered, skipping"
    STATUS_MARKET="already present"
else
    # Merge: .extraKnownMarketplaces.cameronfreer = {source:{source:"github",repo:"cameronfreer/lean4-skills"}}
    if _jq_inplace '.extraKnownMarketplaces = (.extraKnownMarketplaces // {}) | .extraKnownMarketplaces.cameronfreer = {"source":{"source":"github","repo":"cameronfreer/lean4-skills"}}'; then
        if [ "$DRY_RUN" = "1" ]; then
            STATUS_MARKET="dry-run"
        else
            STATUS_MARKET="installed"
            _info "  marketplace registered"
        fi
    else
        _warn "failed to register marketplace"
        STATUS_MARKET="failed"
    fi
fi

# ------------------------------------------------------------------------------
# Section D — enable lean4@cameronfreer plugin
# ------------------------------------------------------------------------------

_info ""
_info "[D] Enabling lean4@cameronfreer plugin..."

STATUS_PLUGIN="unknown"
_plugin_enabled=0
if [ "$DRY_RUN" != "1" ] && [ -f "$SETTINGS_FILE" ]; then
    _val=$(jq -r '.enabledPlugins["lean4@cameronfreer"] // false' "$SETTINGS_FILE" 2>/dev/null || echo "false")
    if [ "$_val" = "true" ]; then
        _plugin_enabled=1
    fi
fi

if [ "$_plugin_enabled" = "1" ]; then
    _info "  plugin already enabled, skipping"
    STATUS_PLUGIN="already present"
else
    if _jq_inplace '.enabledPlugins = (.enabledPlugins // {}) | .enabledPlugins["lean4@cameronfreer"] = true'; then
        if [ "$DRY_RUN" = "1" ]; then
            STATUS_PLUGIN="dry-run"
        else
            STATUS_PLUGIN="installed"
            _info "  plugin enabled"
        fi
    else
        _warn "failed to enable plugin"
        STATUS_PLUGIN="failed"
    fi
fi

_info "  ⚠️  Before trusting the cameronfreer/lean4-skills plugin, run \`/skill-scanner\` on its hooks (especially validate_user_prompt.py)."

# ------------------------------------------------------------------------------
# Section E — PostToolUse lake-build hook
# ------------------------------------------------------------------------------

_info ""
_info "[E] PostToolUse lake-build hook..."

HOOK_DIR="$HOME/.claude/hooks"
HOOK_PATH="$HOOK_DIR/lake-build-on-edit.sh"
HOOK_REGISTERED_CMD='~/.claude/hooks/lake-build-on-edit.sh'

# Desired script content. Single-quoted heredoc — NO expansion here.
read -r -d '' DESIRED_HOOK_CONTENT <<'HOOK_EOF' || true
#!/usr/bin/env bash
# PostToolUse hook: after an Edit/Write to a .lean file, lake-build the
# containing module and inject the result as a system message. Gates on
# lakefile.toml presence so non-Lean projects pay no cost.
set -euo pipefail

INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
[[ "$FILE" =~ \.lean$ ]] || exit 0
[[ -n "${CLAUDE_PROJECT_DIR:-}" ]] || exit 0
[[ -f "$CLAUDE_PROJECT_DIR/lakefile.toml" || -f "$CLAUDE_PROJECT_DIR/lakefile.lean" ]] || exit 0
[[ -f "$CLAUDE_PROJECT_DIR/.lake-build-disabled" ]] && exit 0

MODULE=$(python3 -c "import os,sys; p=sys.argv[1]; b=sys.argv[2]; r=os.path.relpath(p,b).removesuffix('.lean').replace('/', '.'); print(r)" "$FILE" "$CLAUDE_PROJECT_DIR" 2>/dev/null || echo "")
[[ -z "$MODULE" ]] && exit 0

cd "$CLAUDE_PROJECT_DIR" || exit 0
OUT=$(timeout 120 lake build "$MODULE" 2>&1 | tail -40 || true)
printf 'lake build %s:\n%s\n' "$MODULE" "$OUT"
HOOK_EOF

STATUS_HOOK_SCRIPT="unknown"
STATUS_HOOK_REG="unknown"

# ---- E.1: write script file idempotently by sha256 compare ----
_desired_sha=$(printf '%s\n' "$DESIRED_HOOK_CONTENT" | shasum -a 256 | awk '{print $1}')

_existing_sha=""
if [ -f "$HOOK_PATH" ]; then
    _existing_sha=$(shasum -a 256 "$HOOK_PATH" 2>/dev/null | awk '{print $1}')
fi

if [ -n "$_existing_sha" ] && [ "$_existing_sha" = "$_desired_sha" ]; then
    _info "  hook script already present and unchanged, skipping"
    STATUS_HOOK_SCRIPT="already present"
else
    if [ "$DRY_RUN" = "1" ]; then
        echo "DRY-RUN: would mkdir -p $HOOK_DIR"
        echo "DRY-RUN: would write $HOOK_PATH (sha256=$_desired_sha) and chmod 755"
        STATUS_HOOK_SCRIPT="dry-run"
    else
        mkdir -p "$HOOK_DIR"
        # Write atomically: tmp + mv.
        _tmp="${HOOK_PATH}.tmp"
        printf '%s\n' "$DESIRED_HOOK_CONTENT" > "$_tmp"
        chmod 755 "$_tmp"
        mv "$_tmp" "$HOOK_PATH"
        if [ -z "$_existing_sha" ]; then
            STATUS_HOOK_SCRIPT="installed"
            _info "  hook script written to $HOOK_PATH"
        else
            STATUS_HOOK_SCRIPT="updated"
            _info "  hook script updated at $HOOK_PATH"
        fi
    fi
fi

# ---- E.2: register hook in ~/.claude/settings.json PostToolUse ----
_hook_already_registered=0
if [ "$DRY_RUN" != "1" ] && [ -f "$SETTINGS_FILE" ]; then
    if jq -e --arg cmd "$HOOK_REGISTERED_CMD" '
            (.hooks.PostToolUse // []) as $arr
            | any($arr[]?; (.hooks // []) | any(.; .command == $cmd))
        ' "$SETTINGS_FILE" >/dev/null 2>&1; then
        _hook_already_registered=1
    fi
fi

if [ "$_hook_already_registered" = "1" ]; then
    _info "  hook registration already present, skipping"
    STATUS_HOOK_REG="already present"
else
    # Append entry to .hooks.PostToolUse (create arrays as needed, preserve existing).
    _reg_program='
        .hooks = (.hooks // {})
        | .hooks.PostToolUse = (.hooks.PostToolUse // [])
        | .hooks.PostToolUse += [{
            "matcher": "Edit|Write|MultiEdit",
            "hooks": [
              {
                "type": "command",
                "command": $cmd,
                "timeout": 150
              }
            ]
          }]
    '
    if _jq_inplace "$_reg_program" --arg cmd "$HOOK_REGISTERED_CMD"; then
        if [ "$DRY_RUN" = "1" ]; then
            STATUS_HOOK_REG="dry-run"
        else
            STATUS_HOOK_REG="installed"
            _info "  hook registered in PostToolUse"
        fi
    else
        _warn "failed to register hook"
        STATUS_HOOK_REG="failed"
    fi
fi

# ------------------------------------------------------------------------------
# Section F — final summary
# ------------------------------------------------------------------------------

_info ""
_info "=========================================="
_info "  Lean 4 tooling install — summary"
_info "=========================================="
_info "  ✓ lean-lsp-mcp          : $STATUS_MCP"
_info "  ✓ lean4-skills market.  : $STATUS_MARKET"
_info "  ✓ lean4@cameronfreer    : $STATUS_PLUGIN"
_info "  ✓ lake-build hook (file): $STATUS_HOOK_SCRIPT"
_info "  ✓ lake-build hook (reg) : $STATUS_HOOK_REG"
_info ""
_info "Reminders:"
_info "  - Run \`/skill-scanner\` against the cameronfreer/lean4-skills plugin BEFORE"
_info "    trusting its hooks (especially validate_user_prompt.py)."
_info "  - If the plugin isn't auto-installed after the marketplace update loop,"
_info "    install it explicitly:  claude plugin install lean4@cameronfreer"
_info "  - The lake-build hook only fires in projects that contain a lakefile.toml"
_info "    or lakefile.lean. Drop a sentinel file \`.lake-build-disabled\` in a"
_info "    project root to opt that project out."
_info ""
if [ "$DRY_RUN" = "1" ]; then
    _info "DRY-RUN complete. No state was modified."
fi
exit 0

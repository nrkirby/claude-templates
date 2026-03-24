#!/usr/bin/env bash
set -euo pipefail

# Claude Templates Uninstall Script
# Reverses actions performed by install.sh

# ==============================================================================
# CONFIGURATION
# ==============================================================================

readonly CLAUDE_JSON="$HOME/.claude.json"
readonly CLAUDE_DIR="$HOME/.claude"
readonly LEGACY_CL_SH="$HOME/.local/bin/cl.sh"

# MCP servers added by install.sh (from .mcp.json)
readonly MCP_SERVERS=(
    "context7"
    "tavily"
    "playwright"
    "serena"
    "perplexity-ask"
    "shadcn"
)

# Plugins installed by install.sh (includes both old and new names)
readonly PLUGINS=(
    "ct@claude-templates"
    "superpowers@superpowers-marketplace"
    "playwright-skill@playwright-skill"
)

# Plugin marketplaces added by install.sh (includes both old and new names)
readonly MARKETPLACES=(
    "claude-templates"
    "superpowers-marketplace"
    "playwright-skill"
)

# ==============================================================================
# GLOBAL STATE
# ==============================================================================

WARNINGS=()
DRY_RUN=false

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

add_warning() {
    WARNINGS+=("$1")
}

show_help() {
    echo "Claude Templates Uninstall Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Reverses the actions performed by install.sh."
    echo ""
    echo "Options:"
    echo "  --dry-run     Show what would be removed without removing anything"
    echo "  --help, -h    Show this help message"
}

print_summary() {
    echo ""
    echo "============================================"
    echo "UNINSTALL SUMMARY"
    echo "============================================"
    echo ""

    if [ ${#WARNINGS[@]} -gt 0 ]; then
        echo "WARNINGS:"
        for warning in "${WARNINGS[@]}"; do
            echo "  - $warning"
        done
        echo ""
    fi

    echo "MANUAL STEPS REMAINING:"
    echo "  1. Review ~/.claude/settings.json - sandbox and permission settings"
    echo "     were merged by install.sh and cannot be safely auto-removed."
    echo "  2. Review ~/.claude/CLAUDE.md - may contain your personal modifications."
    echo "     Remove manually if no longer needed."
    echo "  3. Optionally uninstall jscpd: npm uninstall -g jscpd"
    echo "  4. Remove environment variables from your shell config (~/.bashrc or ~/.zshrc):"
    echo "     - PERPLEXITY_API_KEY"
    echo "     - TAVILY_API_KEY"
    echo ""
    echo "============================================"
}

# ==============================================================================
# UNINSTALL FUNCTIONS
# ==============================================================================

uninstall_plugins() {
    echo "Uninstalling Claude plugins..."

    for plugin in "${PLUGINS[@]}"; do
        if [ "$DRY_RUN" = true ]; then
            echo "  [dry-run] Would uninstall plugin: $plugin"
        else
            echo "  Uninstalling $plugin..."
            if claude plugin uninstall "$plugin" 2>/dev/null; then
                echo "  Removed plugin: $plugin"
            else
                add_warning "Could not uninstall plugin $plugin (may not be installed)"
            fi
        fi
    done
}

remove_marketplaces() {
    echo "Removing Claude plugin marketplaces..."

    for marketplace in "${MARKETPLACES[@]}"; do
        if [ "$DRY_RUN" = true ]; then
            echo "  [dry-run] Would remove marketplace: $marketplace"
        else
            echo "  Removing $marketplace..."
            if claude plugin marketplace remove "$marketplace" 2>/dev/null; then
                echo "  Removed marketplace: $marketplace"
            else
                add_warning "Could not remove marketplace $marketplace (may not be installed)"
            fi
        fi
    done
}

remove_mcp_servers() {
    echo "Removing MCP servers from $CLAUDE_JSON..."

    if [ ! -f "$CLAUDE_JSON" ]; then
        echo "  $CLAUDE_JSON not found, skipping"
        return 0
    fi

    if ! jq empty "$CLAUDE_JSON" 2>/dev/null; then
        add_warning "$CLAUDE_JSON is not valid JSON, skipping MCP server removal"
        return 0
    fi

    for server in "${MCP_SERVERS[@]}"; do
        if jq -e ".mcpServers | has(\"$server\")" "$CLAUDE_JSON" > /dev/null 2>&1; then
            if [ "$DRY_RUN" = true ]; then
                echo "  [dry-run] Would remove MCP server: $server"
            else
                if jq "del(.mcpServers[\"$server\"])" "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp" && mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"; then
                    echo "  Removed MCP server: $server"
                else
                    rm -f "$CLAUDE_JSON.tmp"
                    add_warning "Failed to remove MCP server $server"
                fi
            fi
        else
            echo "  MCP server $server not found, skipping"
        fi
    done
}

remove_auto_compact() {
    echo "Checking autoCompactEnabled in $CLAUDE_JSON..."

    if [ ! -f "$CLAUDE_JSON" ]; then
        echo "  $CLAUDE_JSON not found, skipping"
        return 0
    fi

    if ! jq empty "$CLAUDE_JSON" 2>/dev/null; then
        add_warning "$CLAUDE_JSON is not valid JSON, skipping autoCompactEnabled removal"
        return 0
    fi

    if jq -e '.autoCompactEnabled == false' "$CLAUDE_JSON" > /dev/null 2>&1; then
        if [ "$DRY_RUN" = true ]; then
            echo "  [dry-run] Would remove autoCompactEnabled (currently set to false)"
        else
            if jq 'del(.autoCompactEnabled)' "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp" && mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"; then
                echo "  Removed autoCompactEnabled"
            else
                rm -f "$CLAUDE_JSON.tmp"
                add_warning "Failed to remove autoCompactEnabled"
            fi
        fi
    else
        echo "  autoCompactEnabled is not set to false, skipping"
    fi
}

warn_sandbox_settings() {
    echo "Checking sandbox settings..."

    if [ -f "$CLAUDE_DIR/settings.json" ]; then
        add_warning "~/.claude/settings.json contains sandbox/permission settings merged by install.sh. These cannot be safely auto-removed. Please review manually."
    else
        echo "  ~/.claude/settings.json not found, nothing to warn about"
    fi
}

warn_claude_md() {
    echo "Checking ~/.claude/CLAUDE.md..."

    if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
        add_warning "~/.claude/CLAUDE.md exists and may contain your personal modifications. Review and remove manually if desired."
    else
        echo "  ~/.claude/CLAUDE.md not found, nothing to warn about"
    fi
}

remove_legacy_cl_sh() {
    echo "Checking for legacy ~/.local/bin/cl.sh..."

    if [ -f "$LEGACY_CL_SH" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "  [dry-run] Would remove $LEGACY_CL_SH"
        else
            if rm -f "$LEGACY_CL_SH"; then
                echo "  Removed $LEGACY_CL_SH"
            else
                add_warning "Failed to remove $LEGACY_CL_SH"
            fi
        fi
    else
        echo "  $LEGACY_CL_SH not found, skipping"
    fi
}

# ==============================================================================
# ARGUMENT PARSING
# ==============================================================================

for arg in "$@"; do
    case "$arg" in
        --dry-run)
            DRY_RUN=true
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg"
            echo ""
            show_help
            exit 1
            ;;
    esac
done

# ==============================================================================
# MAIN SCRIPT
# ==============================================================================

echo "Claude Templates Uninstall"
if [ "$DRY_RUN" = true ]; then
    echo "(dry-run mode -- no changes will be made)"
fi
echo ""

# Check prerequisites
if ! command -v claude &> /dev/null; then
    add_warning "claude CLI not found. Skipping plugin and marketplace removal."
    echo "Skipping plugin and marketplace removal (claude CLI not found)."
    echo ""
else
    uninstall_plugins
    echo ""

    remove_marketplaces
    echo ""
fi

if ! command -v jq &> /dev/null; then
    add_warning "jq not found. Skipping MCP server and autoCompactEnabled removal from ~/.claude.json."
    echo "Skipping JSON config cleanup (jq not found)."
else
    remove_mcp_servers
    echo ""

    remove_auto_compact
fi
echo ""

warn_sandbox_settings
echo ""

warn_claude_md
echo ""

remove_legacy_cl_sh
echo ""

print_summary

#!/usr/bin/env bash

# Claude Templates Update Script
# Discovers and updates all installed Claude plugins and npm global packages.
# Compatible with bash and zsh on macOS and Linux.

set -euo pipefail

# Script directory (for sourcing config)
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared configuration (TOOLS, SKILLS, MARKETPLACES, PLUGINS)
# shellcheck source=config.sh
source "$SCRIPT_DIR/config.sh"

# Load all tool scripts from tools/ directory
for _tool_script in "$SCRIPT_DIR"/tools/*.sh; do
    # shellcheck source=/dev/null
    source "$_tool_script"
done

# ==============================================================================
# TRACKING
# ==============================================================================

WARNINGS=()
ERRORS=()
UPDATED_PLUGINS=0
TOTAL_PLUGINS=0
UPDATED_TOOLS=0
TOTAL_TOOLS=0
UPDATED_SKILLS=0
TOTAL_SKILLS=0

add_warning() { WARNINGS+=("$1"); }
add_error() { ERRORS+=("$1"); }

# ==============================================================================
# UPDATE FUNCTIONS
# ==============================================================================

update_marketplaces() {
    echo "Updating all Claude plugin marketplaces..."
    echo ""

    # 'claude plugin marketplace update' with no args updates all marketplaces
    if claude plugin marketplace update 2>/dev/null; then
        echo "  All marketplaces updated."
    else
        add_warning "Failed to update marketplaces"
    fi

    echo ""
}

update_plugins() {
    echo "Discovering installed Claude plugins..."
    echo ""

    local plugin_json
    plugin_json=$(claude plugin list --json 2>/dev/null || echo "[]")

    # Extract plugin identifiers (name@marketplace) from JSON array
    local plugin_names
    plugin_names=$(echo "$plugin_json" | jq -r '.[] | if .marketplace then "\(.name)@\(.marketplace)" else .name end' 2>/dev/null || echo "")

    if [ -z "$plugin_names" ]; then
        echo "  No plugins installed."
        echo ""
        return
    fi

    TOTAL_PLUGINS=$(echo "$plugin_names" | wc -l | tr -d ' ')
    echo "  Found $TOTAL_PLUGINS installed plugin(s):"
    echo "$plugin_names" | while read -r p; do echo "    - $p"; done
    echo ""

    echo "Updating plugins..."
    echo ""

    while IFS= read -r plugin; do
        [ -z "$plugin" ] && continue
        echo "  Updating: $plugin..."
        if claude plugin update "$plugin" 2>/dev/null; then
            echo "  Updated: $plugin"
            ((UPDATED_PLUGINS++)) || true
        else
            add_warning "Failed to update plugin: $plugin"
        fi
    done <<< "$plugin_names"

    echo ""
}

update_tools() {
    echo "Updating CLI tools..."
    echo ""

    if [ ${#TOOLS[@]} -eq 0 ]; then
        echo "  No tools defined in config.sh."
        echo ""
        return
    fi

    TOTAL_TOOLS=${#TOOLS[@]}
    echo "  Found $TOTAL_TOOLS tool(s) to update:"
    for t in "${TOOLS[@]}"; do echo "    - $t"; done
    echo ""

    local os_type
    os_type="$(uname -s)"
    case "$os_type" in
        Darwin) os_type="macos" ;;
        Linux)  os_type="linux" ;;
        *)      os_type="unknown" ;;
    esac

    for tool in "${TOOLS[@]}"; do
        echo "  Updating: $tool..."
        if "update_${tool}" "$os_type" 2>/dev/null; then
            ((UPDATED_TOOLS++)) || true
        else
            add_warning "Failed to update tool: $tool"
        fi
    done

    echo ""
}

update_skills() {
    echo "Updating globally installed skills..."
    echo ""

    if ! command -v npx &> /dev/null; then
        add_error "npx not found, skipping skills update"
        return
    fi

    if [ ${#SKILLS[@]} -eq 0 ]; then
        echo "  No skills defined in config.sh."
        echo ""
        return
    fi

    TOTAL_SKILLS=${#SKILLS[@]}
    echo "  Found $TOTAL_SKILLS skill(s) to update:"
    for s in "${SKILLS[@]}"; do echo "    - $s"; done
    echo ""

    for skill in "${SKILLS[@]}"; do
        echo "  Updating: $skill..."
        # shellcheck disable=SC2086
        if npx skills add $skill -g --all 2>/dev/null; then
            echo "  Updated: $skill"
            ((UPDATED_SKILLS++)) || true
        else
            add_warning "Failed to update skill: $skill"
        fi
    done

    echo ""
}

# ==============================================================================
# SUMMARY
# ==============================================================================

print_summary() {
    echo "============================================"
    echo "UPDATE SUMMARY"
    echo "============================================"
    echo ""
    echo "  CLI tools updated:      $UPDATED_TOOLS / $TOTAL_TOOLS"
    echo "  Claude plugins updated: $UPDATED_PLUGINS / $TOTAL_PLUGINS"
    echo "  Skills updated:         $UPDATED_SKILLS / $TOTAL_SKILLS"
    echo ""

    if [ ${#WARNINGS[@]} -gt 0 ]; then
        echo "WARNINGS:"
        for warning in "${WARNINGS[@]}"; do
            echo "  - $warning"
        done
        echo ""
    fi

    if [ ${#ERRORS[@]} -gt 0 ]; then
        echo "ERRORS:"
        for error in "${ERRORS[@]}"; do
            echo "  ! $error"
        done
        echo ""
    fi

    if [ ${#WARNINGS[@]} -eq 0 ] && [ ${#ERRORS[@]} -eq 0 ]; then
        echo "All updates completed successfully!"
    fi

    echo "============================================"
}

# ==============================================================================
# MAIN
# ==============================================================================

echo "Starting Claude Templates update..."
echo ""

# Check prerequisites
if ! command -v claude &> /dev/null; then
    echo "Error: claude command not found. Run install.sh first."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for JSON parsing. Install it with: brew install jq"
    exit 1
fi

update_tools
update_marketplaces
update_plugins
update_skills
print_summary

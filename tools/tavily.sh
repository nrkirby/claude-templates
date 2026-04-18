#!/usr/bin/env bash

# Tavily CLI - install, update, and uninstall functions
# Requires: critical_error, add_warning functions from parent script
# Uses pipx for safe installation (avoids PEP 668 issues on Ubuntu 24+, modern macOS)

_ensure_pipx() {
    if command -v pipx &> /dev/null; then
        return 0
    fi

    # brew is a prerequisite for this script (validated in install.sh)
    echo "pipx not found, installing via brew..."
    if ! brew install pipx; then
        return 1
    fi
    pipx ensurepath 2>/dev/null || true

    # Ensure pipx bin dir is on PATH for the current session
    # (ensurepath only modifies rc files, doesn't affect the running shell)
    local pipx_bin="${PIPX_BIN_DIR:-$HOME/.local/bin}"
    if [[ ":$PATH:" != *":$pipx_bin:"* ]]; then
        export PATH="$pipx_bin:$PATH"
    fi
}

install_tavily() {
    echo "Checking for Tavily CLI..."

    if command -v tvly &> /dev/null; then
        echo "Tavily CLI already installed"
        return 0
    fi

    echo "Tavily CLI not found. Installing via pipx..."

    if ! _ensure_pipx; then
        critical_error "Failed to install pipx (required for Tavily CLI)"
    fi

    if ! pipx install tavily-cli; then
        critical_error "Failed to install Tavily CLI"
    fi

    if ! command -v tvly &> /dev/null; then
        critical_error "Tavily CLI installation appeared to succeed but tvly command is still not available"
    fi

    echo "Tavily CLI installed successfully"
}

update_tavily() {
    echo "Updating Tavily CLI..."

    if ! command -v tvly &> /dev/null; then
        add_warning "Tavily CLI is not installed, skipping update"
        return 0
    fi

    if ! _ensure_pipx; then
        add_warning "pipx not available, cannot update Tavily CLI"
        return 0
    fi

    if pipx upgrade tavily-cli; then
        echo "Tavily CLI updated successfully"
    else
        add_warning "Failed to update Tavily CLI"
    fi
}

uninstall_tavily() {
    echo "Removing Tavily CLI..."

    if ! command -v tvly &> /dev/null; then
        echo "Tavily CLI is not installed, nothing to remove"
        return 0
    fi

    # Try pipx uninstall first, fall back to manual removal
    if command -v pipx &> /dev/null && pipx uninstall tavily-cli 2>/dev/null; then
        echo "Tavily CLI removed via pipx"
        return 0
    fi

    # Manual fallback for non-pipx installations
    local tavily_path
    tavily_path=$(command -v tvly 2>/dev/null)
    if [ -n "$tavily_path" ]; then
        rm -f "$tavily_path" 2>/dev/null || add_warning "Failed to remove Tavily CLI binary at $tavily_path (may need elevated privileges)"
    fi

    echo "Tavily CLI removal complete"
}

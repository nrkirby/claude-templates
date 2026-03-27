#!/usr/bin/env bash

# rtk - Rust Token Killer, token-optimized CLI proxy (https://github.com/rtk-ai/rtk)
# Requires: OS_TYPE variable set to "macos" or "linux"
# Requires: critical_error, add_warning functions from parent script

install_rtk() {
    echo "Checking for rtk..."

    if command -v rtk &> /dev/null; then
        echo "rtk already installed: $(rtk --version)"
        return 0
    fi

    echo "rtk not found. Installing rtk..."
    local os_type="${1:-$OS_TYPE}"

    if [ "$os_type" = "macos" ]; then
        if command -v brew &> /dev/null; then
            echo "Installing rtk via Homebrew..."
            if ! brew install rtk-ai/tap/rtk; then
                critical_error "Failed to install rtk via Homebrew"
            fi
        else
            echo "Homebrew not found, installing rtk via install script..."
            if ! curl -fsSL https://rtk-ai.app/install.sh | bash; then
                critical_error "Failed to install rtk via install script"
            fi
        fi
    else
        if command -v brew &> /dev/null; then
            echo "Installing rtk via Homebrew..."
            if ! brew install rtk-ai/tap/rtk; then
                critical_error "Failed to install rtk via Homebrew"
            fi
        else
            echo "Installing rtk via install script..."
            if ! curl -fsSL https://rtk-ai.app/install.sh | bash; then
                critical_error "Failed to install rtk via install script"
            fi
        fi
    fi

    if ! command -v rtk &> /dev/null; then
        critical_error "rtk installation appeared to succeed but rtk command is still not available"
    fi

    echo "rtk installed successfully: $(rtk --version)"

    # Initialize rtk globally (installs hooks, patches CLAUDE.md, registers in settings.json)
    echo "Initializing rtk globally..."
    if ! rtk init -g --auto-patch; then
        add_warning "rtk installed but 'rtk init -g --auto-patch' failed. Run 'rtk init -g' manually to complete setup."
    fi
}

update_rtk() {
    echo "Updating rtk..."

    if ! command -v rtk &> /dev/null; then
        add_warning "rtk is not installed, skipping update"
        return 0
    fi

    if command -v brew &> /dev/null; then
        brew upgrade rtk 2>/dev/null || echo "rtk already up to date"
    else
        echo "Updating rtk via install script..."
        curl -fsSL https://rtk-ai.app/install.sh | bash 2>/dev/null || add_warning "Failed to update rtk via install script"
    fi

    # Re-run init to update hooks if needed
    rtk init -g --auto-patch 2>/dev/null || add_warning "Failed to update rtk hooks"

    echo "rtk update complete"
}

uninstall_rtk() {
    echo "Removing rtk..."

    if ! command -v rtk &> /dev/null; then
        echo "rtk is not installed, nothing to remove"
        return 0
    fi

    # Remove hooks, docs, and settings.json entries (creates settings.json.bak)
    echo "Removing rtk hooks and configuration..."
    rtk init --uninstall 2>/dev/null || add_warning "Failed to run 'rtk init --uninstall'"

    if command -v brew &> /dev/null; then
        brew uninstall rtk 2>/dev/null || add_warning "Failed to uninstall rtk via Homebrew"
    else
        # curl-installed binary lives at ~/.local/bin/rtk
        if [ -f "$HOME/.local/bin/rtk" ]; then
            rm -f "$HOME/.local/bin/rtk"
            echo "  Removed ~/.local/bin/rtk"
        else
            add_warning "Cannot find rtk binary to remove. Please remove it manually."
        fi
    fi

    echo "rtk removal complete"
}

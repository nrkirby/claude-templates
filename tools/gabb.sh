#!/usr/bin/env bash

# gabb - Local code indexer for semantic code understanding (https://github.com/gabb-software/gabb-cli)
# Requires: critical_error, add_warning functions from parent script

install_gabb() {
    echo "Checking for gabb..."

    if command -v gabb &> /dev/null; then
        echo "gabb already installed: $(gabb --version 2>/dev/null || echo 'version unknown')"
    else
        echo "gabb not found. Installing gabb via Homebrew..."
        if ! brew tap gabb-software/homebrew-tap; then
            critical_error "Failed to add gabb Homebrew tap"
        fi
        if ! brew install gabb; then
            critical_error "Failed to install gabb via Homebrew"
        fi

        if ! command -v gabb &> /dev/null; then
            critical_error "gabb installation appeared to succeed but gabb command is still not available"
        fi

        echo "gabb installed successfully: $(gabb --version 2>/dev/null || echo 'version unknown')"
    fi

    # Install gabb globally (MCP config + skill file into ~/.claude/)
    echo "Installing gabb globally (MCP + skill)..."
    if ! gabb install-global; then
        add_warning "Failed to install gabb globally. Run manually: gabb install-global"
    fi
}

update_gabb() {
    echo "Updating gabb..."

    if ! command -v gabb &> /dev/null; then
        add_warning "gabb is not installed, skipping update"
        return 0
    fi

    brew upgrade gabb 2>/dev/null || echo "gabb already up to date"
    echo "gabb update complete"
}

uninstall_gabb() {
    echo "Removing gabb..."

    if ! command -v gabb &> /dev/null; then
        echo "gabb is not installed, nothing to remove"
        return 0
    fi

    # Remove global MCP config + skill file
    echo "Removing gabb global config..."
    gabb uninstall-global 2>/dev/null || add_warning "Failed to uninstall gabb globally. Run manually: gabb uninstall-global"

    brew uninstall gabb 2>/dev/null || add_warning "Failed to uninstall gabb via Homebrew"
    # Remove the tap too
    brew untap gabb-software/homebrew-tap 2>/dev/null || true

    echo "gabb removal complete"
}

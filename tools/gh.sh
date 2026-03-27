#!/usr/bin/env bash

# GitHub CLI (gh) - install and uninstall functions
# Requires: OS_TYPE variable set to "macos" or "linux"
# Requires: critical_error, add_warning functions from parent script
install_gh() {
    echo "Checking for GitHub CLI (gh)..."

    if command -v gh &> /dev/null; then
        echo "GitHub CLI already installed: $(gh --version | head -1)"
        return 0
    fi

    echo "GitHub CLI not found. Installing gh..."
    local os_type="${1:-$OS_TYPE}"

    if [ "$os_type" = "macos" ]; then
        if ! command -v brew &> /dev/null; then
            critical_error "Homebrew is required to install gh on macOS but is not installed. Please install Homebrew first: https://brew.sh"
        fi
        echo "Installing gh via Homebrew..."
        if ! brew install gh; then
            critical_error "Failed to install gh via Homebrew"
        fi
    else
        if command -v apt-get &> /dev/null; then
            echo "Installing gh via apt-get..."
            if ! (sudo mkdir -p /etc/apt/keyrings \
                && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
                && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
                && sudo apt-get update \
                && sudo apt-get install -y gh); then
                critical_error "Failed to install gh via apt-get"
            fi
        elif command -v dnf &> /dev/null; then
            echo "Installing gh via dnf..."
            if ! (sudo dnf install -y 'dnf-command(config-manager)' \
                && sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo \
                && sudo dnf install -y gh); then
                critical_error "Failed to install gh via dnf"
            fi
        elif command -v yum &> /dev/null; then
            echo "Installing gh via yum..."
            if ! (sudo yum install -y yum-utils \
                && sudo yum-config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo \
                && sudo yum install -y gh); then
                critical_error "Failed to install gh via yum"
            fi
        else
            critical_error "Could not find a supported package manager (apt-get, dnf, or yum) to install gh. Please install gh manually: https://github.com/cli/cli#installation"
        fi
    fi

    if ! command -v gh &> /dev/null; then
        critical_error "gh installation appeared to succeed but gh command is still not available"
    fi

    echo "GitHub CLI installed successfully"
}

update_gh() {
    echo "Updating GitHub CLI (gh)..."

    if ! command -v gh &> /dev/null; then
        add_warning "GitHub CLI is not installed, skipping update"
        return 0
    fi

    local os_type="${1:-$OS_TYPE}"

    if [ "$os_type" = "macos" ]; then
        if command -v brew &> /dev/null; then
            brew upgrade gh 2>/dev/null || echo "gh already up to date"
        else
            add_warning "Cannot update gh: Homebrew not found"
        fi
    else
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install --only-upgrade -y gh 2>/dev/null || add_warning "Failed to update gh via apt-get"
        elif command -v dnf &> /dev/null; then
            sudo dnf upgrade -y gh 2>/dev/null || add_warning "Failed to update gh via dnf"
        elif command -v yum &> /dev/null; then
            sudo yum upgrade -y gh 2>/dev/null || add_warning "Failed to update gh via yum"
        else
            add_warning "Cannot update gh: no supported package manager found"
        fi
    fi

    echo "GitHub CLI update complete"
}

uninstall_gh() {
    echo "Removing GitHub CLI (gh)..."

    if ! command -v gh &> /dev/null; then
        echo "GitHub CLI is not installed, nothing to remove"
        return 0
    fi

    local os_type="${1:-$OS_TYPE}"

    if [ "$os_type" = "macos" ]; then
        if command -v brew &> /dev/null; then
            brew uninstall gh 2>/dev/null || add_warning "Failed to uninstall gh via Homebrew"
        else
            add_warning "Cannot uninstall gh: Homebrew not found"
        fi
    else
        if command -v apt-get &> /dev/null; then
            sudo apt-get remove -y gh 2>/dev/null || add_warning "Failed to uninstall gh via apt-get"
        elif command -v dnf &> /dev/null; then
            sudo dnf remove -y gh 2>/dev/null || add_warning "Failed to uninstall gh via dnf"
        elif command -v yum &> /dev/null; then
            sudo yum remove -y gh 2>/dev/null || add_warning "Failed to uninstall gh via yum"
        else
            add_warning "Cannot uninstall gh: no supported package manager found"
        fi
    fi

    echo "GitHub CLI removal complete"
}

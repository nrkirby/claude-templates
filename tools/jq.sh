#!/usr/bin/env bash

# jq JSON processor - install and uninstall functions
# Requires: OS_TYPE variable set to "macos" or "linux"
# Requires: critical_error, add_warning functions from parent script
# Note: Linux package manager commands (apt-get, dnf, yum) may require elevated
# privileges. Run the installer with appropriate permissions if needed.

install_jq() {
    echo "Checking for jq..."

    if command -v jq &> /dev/null; then
        echo "jq already installed: $(jq --version)"
        return 0
    fi

    echo "jq not found. Installing jq..."
    local os_type="${1:-$OS_TYPE}"

    if [ "$os_type" = "macos" ]; then
        if ! command -v brew &> /dev/null; then
            critical_error "Homebrew is required to install jq on macOS but is not installed. Please install Homebrew first: https://brew.sh"
        fi
        echo "Installing jq via Homebrew..."
        if ! brew install jq; then
            critical_error "Failed to install jq via Homebrew"
        fi
    else
        if command -v apt-get &> /dev/null; then
            echo "Installing jq via apt-get..."
            if ! (apt-get update && apt-get install -y jq); then
                critical_error "Failed to install jq via apt-get"
            fi
        elif command -v dnf &> /dev/null; then
            echo "Installing jq via dnf..."
            if ! dnf install -y jq; then
                critical_error "Failed to install jq via dnf"
            fi
        elif command -v yum &> /dev/null; then
            echo "Installing jq via yum..."
            if ! yum install -y jq; then
                critical_error "Failed to install jq via yum"
            fi
        else
            critical_error "Could not find a supported package manager (apt-get, dnf, or yum) to install jq. Please install jq manually."
        fi
    fi

    if ! command -v jq &> /dev/null; then
        critical_error "jq installation appeared to succeed but jq command is still not available"
    fi

    echo "jq installed successfully"
}

update_jq() {
    echo "Updating jq..."

    if ! command -v jq &> /dev/null; then
        add_warning "jq is not installed, skipping update"
        return 0
    fi

    local os_type="${1:-$OS_TYPE}"

    if [ "$os_type" = "macos" ]; then
        if command -v brew &> /dev/null; then
            brew upgrade jq 2>/dev/null || echo "jq already up to date"
        else
            add_warning "Cannot update jq: Homebrew not found"
        fi
    else
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install --only-upgrade -y jq 2>/dev/null || add_warning "Failed to update jq via apt-get"
        elif command -v dnf &> /dev/null; then
            dnf upgrade -y jq 2>/dev/null || add_warning "Failed to update jq via dnf"
        elif command -v yum &> /dev/null; then
            yum upgrade -y jq 2>/dev/null || add_warning "Failed to update jq via yum"
        else
            add_warning "Cannot update jq: no supported package manager found"
        fi
    fi

    echo "jq update complete"
}

uninstall_jq() {
    echo "Removing jq..."

    if ! command -v jq &> /dev/null; then
        echo "jq is not installed, nothing to remove"
        return 0
    fi

    local os_type="${1:-$OS_TYPE}"

    if [ "$os_type" = "macos" ]; then
        if command -v brew &> /dev/null; then
            brew uninstall jq 2>/dev/null || add_warning "Failed to uninstall jq via Homebrew"
        else
            add_warning "Cannot uninstall jq: Homebrew not found"
        fi
    else
        if command -v apt-get &> /dev/null; then
            apt-get remove -y jq 2>/dev/null || add_warning "Failed to uninstall jq via apt-get"
        elif command -v dnf &> /dev/null; then
            dnf remove -y jq 2>/dev/null || add_warning "Failed to uninstall jq via dnf"
        elif command -v yum &> /dev/null; then
            yum remove -y jq 2>/dev/null || add_warning "Failed to uninstall jq via yum"
        else
            add_warning "Cannot uninstall jq: no supported package manager found"
        fi
    fi

    echo "jq removal complete"
}

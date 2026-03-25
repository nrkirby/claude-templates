#!/usr/bin/env bash

# jscpd (copy/paste detector) - install, update, and uninstall via npm
# Requires: critical_error, add_warning functions from parent script

_npm_install_jscpd() {
    if npm install -g jscpd@latest 2>/dev/null; then
        return 0
    fi
    echo "Retrying with sudo..."
    if sudo npm install -g jscpd@latest; then
        return 0
    fi
    return 1
}

install_jscpd() {
    echo "Checking for jscpd..."

    if command -v jscpd &> /dev/null; then
        echo "jscpd already installed"
        return 0
    fi

    echo "jscpd not found. Installing..."
    if ! _npm_install_jscpd; then
        critical_error "Failed to install jscpd"
    fi

    echo "jscpd installed successfully"
}

update_jscpd() {
    echo "Updating jscpd..."

    if ! command -v jscpd &> /dev/null; then
        add_warning "jscpd is not installed, skipping update"
        return 0
    fi

    if _npm_install_jscpd; then
        echo "jscpd updated successfully"
    else
        add_warning "Failed to update jscpd"
    fi
}

uninstall_jscpd() {
    echo "Removing jscpd..."

    if ! npm uninstall -g jscpd 2>/dev/null; then
        sudo npm uninstall -g jscpd 2>/dev/null || add_warning "Failed to uninstall jscpd"
    fi

    echo "jscpd removal complete"
}

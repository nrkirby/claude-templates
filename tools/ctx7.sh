#!/usr/bin/env bash

# ctx7 (Context7 CLI) - install, update, and uninstall via npm
# Requires: critical_error, add_warning functions from parent script

_npm_install_ctx7() {
    if npm install -g ctx7@latest 2>/dev/null; then
        return 0
    fi
    echo "Retrying with sudo..."
    if sudo npm install -g ctx7@latest; then
        return 0
    fi
    return 1
}

install_ctx7() {
    echo "Checking for ctx7..."

    if npm list -g ctx7 &> /dev/null; then
        echo "ctx7 already installed"
        return 0
    fi

    echo "ctx7 not found. Installing..."
    if ! _npm_install_ctx7; then
        critical_error "Failed to install ctx7"
    fi

    echo "ctx7 installed successfully"
}

update_ctx7() {
    echo "Updating ctx7..."

    if ! npm list -g ctx7 &> /dev/null; then
        add_warning "ctx7 is not installed, skipping update"
        return 0
    fi

    if _npm_install_ctx7; then
        echo "ctx7 updated successfully"
    else
        add_warning "Failed to update ctx7"
    fi
}

uninstall_ctx7() {
    echo "Removing ctx7..."

    if ! npm uninstall -g ctx7 2>/dev/null; then
        sudo npm uninstall -g ctx7 2>/dev/null || add_warning "Failed to uninstall ctx7"
    fi

    echo "ctx7 removal complete"
}

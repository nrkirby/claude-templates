#!/usr/bin/env bash

# WCAG accessibility auditing tools - install, update, and uninstall via npm
# Installs: @axe-core/cli (runtime auditing), pa11y (batch URL testing)
# Requires: critical_error, add_warning functions from parent script

_npm_install_wcag() {
    npm install -g @axe-core/cli@latest pa11y@latest
}

install_wcag() {
    echo "Checking for WCAG tools..."

    local missing=()

    if ! command -v axe &> /dev/null; then
        missing+=("@axe-core/cli")
    fi

    if ! command -v pa11y &> /dev/null; then
        missing+=("pa11y")
    fi

    if [ ${#missing[@]} -eq 0 ]; then
        echo "WCAG tools already installed"
        return 0
    fi

    echo "Installing WCAG tools: ${missing[*]}..."
    if ! _npm_install_wcag; then
        critical_error "Failed to install WCAG tools"
    fi

    echo "WCAG tools installed successfully (axe-core CLI, pa11y)"
}

update_wcag() {
    echo "Updating WCAG tools..."

    if ! command -v axe &> /dev/null && ! command -v pa11y &> /dev/null; then
        add_warning "WCAG tools are not installed, skipping update"
        return 0
    fi

    if _npm_install_wcag; then
        echo "WCAG tools updated successfully"
    else
        add_warning "Failed to update WCAG tools"
    fi
}

uninstall_wcag() {
    echo "Removing WCAG tools..."

    npm uninstall -g @axe-core/cli 2>/dev/null
    npm uninstall -g pa11y 2>/dev/null

    echo "WCAG tools removal complete"
}

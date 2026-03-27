#!/usr/bin/env bash

# agent-browser - AI-first browser automation CLI from Vercel (https://github.com/vercel-labs/agent-browser)
# Requires: critical_error, add_warning functions from parent script

install_agent_browser() {
    echo "Checking for agent-browser..."

    if command -v agent-browser &> /dev/null; then
        echo "agent-browser already installed"
        return 0
    fi

    echo "agent-browser not found. Installing..."
    if ! npm install -g agent-browser@latest; then
        critical_error "Failed to install agent-browser"
    fi

    echo "agent-browser installed successfully"

    echo "Installing browser (Chrome for Testing)..."
    if ! agent-browser install; then
        add_warning "Failed to install Chrome for Testing via agent-browser install"
    fi
}

update_agent_browser() {
    echo "Updating agent-browser..."

    if ! command -v agent-browser &> /dev/null; then
        add_warning "agent-browser is not installed, skipping update"
        return 0
    fi

    if agent-browser upgrade; then
        echo "agent-browser updated successfully"
    else
        add_warning "Failed to update agent-browser"
    fi
}

uninstall_agent_browser() {
    echo "Removing agent-browser..."

    if ! npm uninstall -g agent-browser 2>/dev/null; then
        add_warning "Failed to uninstall agent-browser"
    fi

    echo "agent-browser removal complete"
}

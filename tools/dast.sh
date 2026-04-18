#!/usr/bin/env bash

# DAST scanning tools - install, update, and uninstall
# Installs: Nuclei (brew), ZAP Docker image (optional, requires Docker)
# Requires: critical_error, add_warning functions from parent script

install_dast() {
    echo "Checking for DAST tools..."

    # Nuclei — single binary, no Docker needed
    if command -v nuclei &> /dev/null; then
        echo "Nuclei already installed: $(nuclei -version 2>&1 | head -1)"
    else
        echo "Nuclei not found. Installing Nuclei via Homebrew..."
        if ! brew install nuclei; then
            critical_error "Failed to install Nuclei via Homebrew"
        fi
        echo "Nuclei installed successfully"
    fi

    # ZAP — requires Docker
    if command -v docker &>/dev/null; then
        echo "Pulling ZAP Docker image..."
        if docker pull zaproxy/zap-stable; then
            echo "ZAP Docker image pulled successfully"
        else
            add_warning "Failed to pull ZAP Docker image"
        fi
    else
        add_warning "Docker not found. ZAP deep scanning (Tier 2) requires Docker. Nuclei (Tier 1) will work fine without it. Install Docker: https://docs.docker.com/get-docker/"
    fi
}

update_dast() {
    echo "Updating DAST tools..."

    # Update Nuclei
    if command -v nuclei &> /dev/null; then
        brew upgrade nuclei 2>/dev/null || echo "Nuclei already up to date"
        # Update Nuclei templates
        nuclei -update-templates 2>/dev/null || true
    else
        add_warning "Nuclei is not installed, skipping update"
    fi

    # Update ZAP Docker image
    if command -v docker &>/dev/null; then
        docker pull zaproxy/zap-stable 2>/dev/null || add_warning "Failed to update ZAP Docker image"
    fi
}

uninstall_dast() {
    echo "Removing DAST tools..."

    # Remove Nuclei
    brew uninstall nuclei 2>/dev/null || true

    # Remove ZAP Docker image
    if command -v docker &>/dev/null; then
        docker rmi zaproxy/zap-stable 2>/dev/null || true
    fi

    echo "DAST tools removal complete"
}

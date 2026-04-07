#!/usr/bin/env bash

# DAST scanning tools - install, update, and uninstall
# Installs: Nuclei (brew/go), ZAP Docker image (optional, requires Docker)
# Requires: critical_error, add_warning functions from parent script

install_dast() {
    echo "Checking for DAST tools..."

    # Nuclei — single binary, no Docker needed
    if command -v nuclei &> /dev/null; then
        echo "Nuclei already installed: $(nuclei -version 2>&1 | head -1)"
    else
        echo "Nuclei not found. Installing..."
        if command -v brew &>/dev/null; then
            if ! brew install nuclei; then
                critical_error "Failed to install Nuclei via Homebrew"
            fi
        elif command -v go &>/dev/null; then
            if ! go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest; then
                critical_error "Failed to install Nuclei via go install"
            fi
        else
            critical_error "Cannot install Nuclei: neither brew nor go found. Install manually: https://docs.projectdiscovery.io/tools/nuclei/install"
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
        echo ""
        echo "WARNING: Docker not found. ZAP deep scanning (Tier 2) requires Docker."
        echo "  Nuclei (Tier 1) will work fine without it."
        echo "  Install Docker: https://docs.docker.com/get-docker/"
    fi
}

update_dast() {
    echo "Updating DAST tools..."

    # Update Nuclei
    if command -v nuclei &> /dev/null; then
        if command -v brew &>/dev/null; then
            brew upgrade nuclei 2>/dev/null || echo "Nuclei already up to date"
        elif command -v go &>/dev/null; then
            go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
        fi
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
    if command -v brew &>/dev/null; then
        brew uninstall nuclei 2>/dev/null || true
    fi
    # Note: go-installed binaries must be removed manually from GOPATH/bin

    # Remove ZAP Docker image
    if command -v docker &>/dev/null; then
        docker rmi zaproxy/zap-stable 2>/dev/null || true
    fi

    echo "DAST tools removal complete"
}

#!/usr/bin/env bash

# fd - fast find alternative (https://github.com/sharkdp/fd)
# Requires: OS_TYPE variable set to "macos" or "linux"
# Requires: critical_error, add_warning functions from parent script
install_fd() {
    echo "Checking for fd..."

    if command -v fd &> /dev/null; then
        echo "fd already installed: $(fd --version)"
        return 0
    fi

    echo "fd not found. Installing fd..."
    local os_type="${1:-$OS_TYPE}"

    if [ "$os_type" = "macos" ]; then
        if ! command -v brew &> /dev/null; then
            critical_error "Homebrew is required to install fd on macOS but is not installed. Please install Homebrew first: https://brew.sh"
        fi
        echo "Installing fd via Homebrew..."
        if ! brew install fd; then
            critical_error "Failed to install fd via Homebrew"
        fi
    else
        if command -v apt-get &> /dev/null; then
            echo "Installing fd via apt-get..."
            if ! (sudo apt-get update && sudo apt-get install -y fd-find); then
                critical_error "Failed to install fd via apt-get"
            fi
            # On Debian/Ubuntu the binary is 'fdfind' to avoid conflict with fdclone
            if ! command -v fd &> /dev/null && command -v fdfind &> /dev/null; then
                echo "Creating symlink: fd -> fdfind"
                sudo ln -sf "$(which fdfind)" /usr/local/bin/fd
            fi
        elif command -v dnf &> /dev/null; then
            echo "Installing fd via dnf..."
            if ! sudo dnf install -y fd-find; then
                critical_error "Failed to install fd via dnf"
            fi
        elif command -v yum &> /dev/null; then
            echo "Installing fd via yum..."
            if ! sudo yum install -y fd-find; then
                critical_error "Failed to install fd via yum"
            fi
        else
            critical_error "Could not find a supported package manager (apt-get, dnf, or yum) to install fd. Please install fd manually: https://github.com/sharkdp/fd#installation"
        fi
    fi

    if ! command -v fd &> /dev/null; then
        critical_error "fd installation appeared to succeed but fd command is still not available"
    fi

    echo "fd installed successfully: $(fd --version)"

    # Configure find -> fd alias in shell RC files
    echo "Configuring find -> fd alias..."
    local alias_line="alias find='fd'"
    local alias_added=false

    for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ ! -f "$rc_file" ]; then
            echo "  $rc_file does not exist, skipping"
            continue
        fi

        if grep -qF "alias find=" "$rc_file"; then
            echo "  Alias 'find' already present in $rc_file, skipping"
        else
            echo "" >> "$rc_file"
            echo "# Use fd as find replacement (added by claude-templates install.sh)" >> "$rc_file"
            echo "$alias_line" >> "$rc_file"
            echo "  Added 'find' alias to $rc_file"
            alias_added=true
        fi
    done

    if [ "$alias_added" = true ]; then
        echo ""
        echo "  NOTE: Run 'source ~/.bashrc' (or ~/.zshrc) or open a new terminal for the alias to take effect."
    fi

    # Message for other shells
    echo ""
    echo "  For other shells (fish, nushell, etc.), add the equivalent alias manually:"
    echo "    fish:    alias find fd; funcsave find"
    echo "    nushell: alias find = fd  (add to config.nu)"
}

update_fd() {
    echo "Updating fd..."

    if ! command -v fd &> /dev/null; then
        add_warning "fd is not installed, skipping update"
        return 0
    fi

    local os_type="${1:-$OS_TYPE}"

    if [ "$os_type" = "macos" ]; then
        if command -v brew &> /dev/null; then
            brew upgrade fd 2>/dev/null || echo "fd already up to date"
        else
            add_warning "Cannot update fd: Homebrew not found"
        fi
    else
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install --only-upgrade -y fd-find 2>/dev/null || add_warning "Failed to update fd via apt-get"
        elif command -v dnf &> /dev/null; then
            sudo dnf upgrade -y fd-find 2>/dev/null || add_warning "Failed to update fd via dnf"
        elif command -v yum &> /dev/null; then
            sudo yum upgrade -y fd-find 2>/dev/null || add_warning "Failed to update fd via yum"
        else
            add_warning "Cannot update fd: no supported package manager found"
        fi
    fi

    echo "fd update complete"
}

uninstall_fd() {
    echo "Removing fd..."

    if ! command -v fd &> /dev/null; then
        echo "fd is not installed, nothing to remove"
        return 0
    fi

    local os_type="${1:-$OS_TYPE}"

    if [ "$os_type" = "macos" ]; then
        if command -v brew &> /dev/null; then
            brew uninstall fd 2>/dev/null || add_warning "Failed to uninstall fd via Homebrew"
        else
            add_warning "Cannot uninstall fd: Homebrew not found"
        fi
    else
        # Remove symlink if we created one
        if [ -L /usr/local/bin/fd ]; then
            sudo rm -f /usr/local/bin/fd
        fi
        if command -v apt-get &> /dev/null; then
            sudo apt-get remove -y fd-find 2>/dev/null || add_warning "Failed to uninstall fd via apt-get"
        elif command -v dnf &> /dev/null; then
            sudo dnf remove -y fd-find 2>/dev/null || add_warning "Failed to uninstall fd via dnf"
        elif command -v yum &> /dev/null; then
            sudo yum remove -y fd-find 2>/dev/null || add_warning "Failed to uninstall fd via yum"
        else
            add_warning "Cannot uninstall fd: no supported package manager found"
        fi
    fi

    # Remove find -> fd alias from shell RC files
    echo "Removing find -> fd alias..."
    for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ ! -f "$rc_file" ]; then
            continue
        fi

        if grep -qF "alias find='fd'" "$rc_file"; then
            sed -i.bak '/# Use fd as find replacement (added by claude-templates install.sh)/d' "$rc_file"
            sed -i.bak "/alias find='fd'/d" "$rc_file"
            rm -f "${rc_file}.bak"
            echo "  Removed find alias from $rc_file"
        fi
    done

    echo "fd removal complete"
}

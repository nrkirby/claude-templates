#!/usr/bin/env bash

# tac (reverse cat) - install/update/uninstall
# Linux: ships with GNU coreutils, present by default. Intentionally NOT routed
#        through brew here — every Linux distro installs coreutils with the base
#        system, so if `tac` is missing the OS itself is broken. Error out
#        cleanly instead of papering over it with a brew install (which would
#        also force Linuxbrew's coreutils into PATH ahead of the distro's).
# macOS: not present by default; provided by `brew install coreutils` as `gtac`.
#        We also create a `tac` symlink in $(brew --prefix)/bin so scripts
#        that call `tac` literally work without PATH manipulation.
# Requires: critical_error, add_warning functions from parent script

_tac_macos_symlink() {
    local brew_prefix
    brew_prefix=$(brew --prefix 2>/dev/null) || return 1
    local gtac_path="${brew_prefix}/opt/coreutils/libexec/gnubin/tac"
    local tac_link="${brew_prefix}/bin/tac"

    if [ ! -x "$gtac_path" ]; then
        return 1
    fi

    if [ -L "$tac_link" ] && [ "$(readlink "$tac_link")" = "$gtac_path" ]; then
        return 0
    fi

    ln -sfn "$gtac_path" "$tac_link"
}

install_tac() {
    echo "Checking for tac..."

    if command -v tac &> /dev/null; then
        echo "tac already installed: $(command -v tac)"
        return 0
    fi

    case "$(uname -s)" in
        Darwin)
            echo "tac not found on macOS. Installing via Homebrew coreutils..."
            if ! brew list coreutils &> /dev/null; then
                if ! brew install coreutils; then
                    critical_error "Failed to install coreutils via Homebrew"
                fi
            fi

            if ! _tac_macos_symlink; then
                critical_error "coreutils installed but failed to create tac symlink in \$(brew --prefix)/bin"
            fi

            if ! command -v tac &> /dev/null; then
                critical_error "tac installation completed but tac command is still not on PATH (check that \$(brew --prefix)/bin is in PATH)"
            fi

            echo "tac installed successfully: $(command -v tac)"
            ;;
        Linux)
            critical_error "tac not found on Linux — it should ship with GNU coreutils. Install your distro's coreutils package (e.g. apt install coreutils, dnf install coreutils)."
            ;;
        *)
            critical_error "Unsupported OS for tac install: $(uname -s)"
            ;;
    esac
}

update_tac() {
    echo "Updating tac..."

    case "$(uname -s)" in
        Darwin)
            if ! brew list coreutils &> /dev/null; then
                add_warning "coreutils not installed via Homebrew, skipping update"
                return 0
            fi
            brew upgrade coreutils 2>/dev/null || echo "coreutils already up to date"
            _tac_macos_symlink || add_warning "coreutils updated but tac symlink refresh failed"
            echo "tac update complete"
            ;;
        Linux)
            echo "tac update on Linux: managed by your distro's package manager — skipping"
            ;;
        *)
            add_warning "Unsupported OS for tac update: $(uname -s)"
            ;;
    esac
}

uninstall_tac() {
    echo "Removing tac..."

    case "$(uname -s)" in
        Darwin)
            local brew_prefix tac_link
            brew_prefix=$(brew --prefix 2>/dev/null) || true
            tac_link="${brew_prefix:+$brew_prefix/bin/tac}"

            if [ -n "$tac_link" ] && [ -L "$tac_link" ]; then
                rm -f "$tac_link" 2>/dev/null || add_warning "Failed to remove tac symlink at $tac_link"
            fi

            # Do NOT uninstall coreutils — other tools may depend on it.
            echo "tac symlink removed (coreutils kept; other tools may need it)"
            ;;
        Linux)
            echo "tac on Linux is part of coreutils, not removed"
            ;;
        *)
            add_warning "Unsupported OS for tac uninstall: $(uname -s)"
            ;;
    esac
}

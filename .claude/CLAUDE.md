## Tool Installer Convention

<brew_only_installers>
→ Writing/editing an installer under `tools/*.sh` (non-optional; `tools/optional/*` is exempt) → Does Homebrew ship a formula (or tap) for this tool on BOTH macOS and Linux (Linuxbrew)?
  Yes → Use `brew install` in a single unified path. Do NOT add curl/go/npm/pip fallback branches and do NOT branch on `uname -s` to pick a non-brew path. `install.sh` already hard-fails if brew is missing, so fallbacks are dead code that bloats the file.
  No → Flag in the script's top-of-file comment that brew is not available for this tool; use the minimal necessary alternative (npm / pipx / curl); keep OS branches only if the non-brew install itself legitimately differs by OS.
</brew_only_installers>

#!/usr/bin/env bash
# Stop hook: run configured linters on files changed since last check.
#
# Reads .claude/linters.json for linter configuration.
# Only lints files that changed since the last check (via git diff hash).
# Reports violations and exits 1 if any found (forces Claude to fix).
# Exits 0 silently if no violations or no changes.
#
# Environment:
#   LINT_GUARD_SKIP=1  — skip all linting for this session

set -euo pipefail

# Skip if disabled
if [ "${LINT_GUARD_SKIP:-}" = "1" ]; then
  exit 0
fi

# Read hook input from stdin
INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

if [ -z "$CWD" ]; then
  exit 0
fi

CONFIG="${CWD}/.claude/linters.json"

# Exit if not configured
if [ ! -f "$CONFIG" ]; then
  exit 0
fi

# Check if Stop hook is enabled in config
ENABLED=$(jq -r '.settings.stop_hook_enabled // true' "$CONFIG")
if [ "$ENABLED" = "false" ]; then
  exit 0
fi

# Read settings
MAX_LINES=$(jq -r '.settings.max_output_lines // 500' "$CONFIG")
TIMEOUT=$(jq -r '.settings.timeout_per_linter_seconds // 30' "$CONFIG")

# --- Detect changed files ---

LAST_CHECK_FILE="${CWD}/.claude/.lint-last-check"
CHANGED_FILES=""

cd "$CWD"

if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  # Git project: get changed files (unstaged + staged)
  CHANGED_FILES=$(git diff --name-only 2>/dev/null; git diff --name-only --cached 2>/dev/null)
  CHANGED_FILES=$(echo "$CHANGED_FILES" | sort -u | grep -v '^$' || true)
else
  # No git: we can't diff, skip (warn once)
  echo "Lint Guard: No git repository detected. Skipping diff-based linting." >&2
  exit 0
fi

# Exit if no changed files
if [ -z "$CHANGED_FILES" ]; then
  exit 0
fi

# Check against last known state (use md5sum on Linux, md5 on macOS)
if command -v md5sum > /dev/null 2>&1; then
  CURRENT_HASH=$(echo "$CHANGED_FILES" | md5sum | cut -d' ' -f1)
else
  CURRENT_HASH=$(echo "$CHANGED_FILES" | md5 -q)
fi

if [ -f "$LAST_CHECK_FILE" ]; then
  LAST_HASH=$(cat "$LAST_CHECK_FILE" 2>/dev/null || echo "")
  if [ "$CURRENT_HASH" = "$LAST_HASH" ]; then
    exit 0
  fi
fi

# --- Run linters ---

LINTER_COUNT=$(jq '.linters | length' "$CONFIG")
ALL_OUTPUT=""
HAS_VIOLATIONS=false

for i in $(seq 0 $((LINTER_COUNT - 1))); do
  LINTER_NAME=$(jq -r ".linters[$i].name" "$CONFIG")
  LINTER_CMD=$(jq -r ".linters[$i].command" "$CONFIG")
  LINTER_GLOB=$(jq -r ".linters[$i].glob" "$CONFIG")

  # Check if linter binary exists (first word of command)
  LINTER_BIN=$(echo "$LINTER_CMD" | awk '{print $1}')
  # Handle npx/bunx prefix — check the actual tool
  case "$LINTER_BIN" in
    npx|bunx|pnpx) ;; # npx handles resolution itself
    *)
      if ! command -v "$LINTER_BIN" > /dev/null 2>&1; then
        continue
      fi
      ;;
  esac

  # Match changed files against glob pattern
  # Note: bash case doesn't support brace expansion like *.{js,ts}
  # so we expand the glob manually if it contains braces
  MATCHING_FILES=""
  EXPANDED_GLOBS=()

  if [[ "$LINTER_GLOB" == *"{"*"}"* ]]; then
    # Extract brace content and expand: *.{js,ts} -> *.js *.ts
    PREFIX="${LINTER_GLOB%%\{*}"
    SUFFIX="${LINTER_GLOB##*\}}"
    BRACE_CONTENT="${LINTER_GLOB#*\{}"
    BRACE_CONTENT="${BRACE_CONTENT%%\}*}"
    IFS=',' read -ra EXTENSIONS <<< "$BRACE_CONTENT"
    for ext in "${EXTENSIONS[@]}"; do
      EXPANDED_GLOBS+=("${PREFIX}${ext}${SUFFIX}")
    done
  else
    EXPANDED_GLOBS+=("$LINTER_GLOB")
  fi

  while IFS= read -r file; do
    [ -z "$file" ] && continue
    MATCHED=false
    BASENAME=$(basename "$file")
    for glob in "${EXPANDED_GLOBS[@]}"; do
      # Try matching against full relative path first (for path-qualified globs)
      # shellcheck disable=SC2254
      case "$file" in
        $glob) MATCHED=true; break ;;
      esac
      # Fall back to matching just the filename (for simple globs like *.py)
      if [ "$MATCHED" = false ]; then
        # shellcheck disable=SC2254
        case "$BASENAME" in
          $glob) MATCHED=true; break ;;
        esac
      fi
    done
    if [ "$MATCHED" = true ]; then
      MATCHING_FILES="${MATCHING_FILES} ${file}"
    fi
  done <<< "$CHANGED_FILES"

  MATCHING_FILES=$(echo "$MATCHING_FILES" | xargs 2>/dev/null || true)

  # Skip if no matching files
  if [ -z "$MATCHING_FILES" ]; then
    continue
  fi

  # Run linter with timeout
  LINTER_OUTPUT=""
  set +e
  # shellcheck disable=SC2086
  LINTER_OUTPUT=$(timeout "${TIMEOUT}s" $LINTER_CMD $MATCHING_FILES 2>&1)
  LINTER_EXIT=$?
  set -e

  # Handle timeout
  if [ $LINTER_EXIT -eq 124 ]; then
    ALL_OUTPUT="${ALL_OUTPUT}"$'\n'"[${LINTER_NAME}] TIMEOUT: linter exceeded ${TIMEOUT}s limit"
    continue
  fi

  # Handle linter results
  # Exit code 1 = violations found (normal for most linters)
  # Exit code 0 = no violations
  # Exit code 2+ = infrastructure error for most linters
  if [ $LINTER_EXIT -ne 0 ] && [ -n "$LINTER_OUTPUT" ]; then
    ALL_OUTPUT="${ALL_OUTPUT}"$'\n'"[${LINTER_NAME}]"$'\n'"${LINTER_OUTPUT}"
    HAS_VIOLATIONS=true
  fi
done

# --- Output ---

# Update last check hash
mkdir -p "${CWD}/.claude"
echo "$CURRENT_HASH" > "$LAST_CHECK_FILE"

# Exit clean if no violations
if [ "$HAS_VIOLATIONS" = false ]; then
  exit 0
fi

# Truncate output to max lines
OUTPUT=$(echo "$ALL_OUTPUT" | head -n "$MAX_LINES")
LINE_COUNT=$(echo "$ALL_OUTPUT" | wc -l | tr -d ' ')

TRUNCATED_MSG=""
if [ "$LINE_COUNT" -gt "$MAX_LINES" ]; then
  TRUNCATED_MSG=$'\n'"... (${LINE_COUNT} total lines, showing first ${MAX_LINES})"
fi

# Print violations report
cat <<REPORT
Lint violations in files you just changed:
${OUTPUT}${TRUNCATED_MSG}

INSTRUCTION: Fix these violations before proceeding. For complexity violations, refactor the function (extract helpers, reduce nesting). For style violations, apply the fix directly. Do not ask — just fix them.
REPORT

exit 1

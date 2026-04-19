#!/bin/bash
input=$(cat)

# --- Extract data ---
MODEL=$(echo "$input" | jq -r '.model.display_name // "—"')
DIR=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "—"')
STYLE=$(echo "$input" | jq -r '.output_style.name // "—"')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
CTX_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
RATE_5H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // 0' | cut -d. -f1)
RATE_7D=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // 0' | cut -d. -f1)
AGENT=$(echo "$input" | jq -r '.agent.name // empty')
WORKTREE=$(echo "$input" | jq -r '.worktree.name // empty')
WT_BRANCH=$(echo "$input" | jq -r '.worktree.branch // empty')

# --- Colors ---
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

# --- Git branch + diff stats (tracked +/-, untracked ?) ---
BRANCH=""
GIT_STATS=""
if git rev-parse --git-dir > /dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null)
  DIFF_PART=$(git diff HEAD --shortstat 2>/dev/null | awk '
    {
      for (i=1; i<=NF; i++) {
        if ($i ~ /insertion/) ins=$(i-1)
        if ($i ~ /deletion/)  del=$(i-1)
      }
      if (ins+0 || del+0) printf "+%d/-%d", ins+0, del+0
    }')
  UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
  GIT_STATS="$DIFF_PART"
  if [ "${UNTRACKED:-0}" -gt 0 ]; then
    [ -n "$GIT_STATS" ] && GIT_STATS="$GIT_STATS "
    GIT_STATS="${GIT_STATS}?${UNTRACKED}"
  fi
fi

# --- Context bar ---
if [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

FILLED=$((PCT / 5))
EMPTY=$((20 - FILLED))
printf -v FILL "%${FILLED}s"
printf -v PAD "%${EMPTY}s"
BAR="${FILL// /▓}${PAD// /░}"

# --- Context size label ---
if [ "$CTX_SIZE" -ge 1000000 ]; then
  CTX_LABEL="1M"
elif [ "$CTX_SIZE" -ge 200000 ]; then
  CTX_LABEL="200k"
else
  CTX_LABEL="${CTX_SIZE}"
fi

# --- Rate limit colors ---
rate_color() {
  local val=$1
  if [ "$val" -ge 90 ]; then echo -ne "$RED"
  elif [ "$val" -ge 70 ]; then echo -ne "$YELLOW"
  else echo -ne "$GREEN"; fi
}

# --- Line 1: folder | branch (+stats) | output style (if non-default) ---
LINE1="${CYAN}📁 ${DIR##*/}${RESET}"
if [ -n "$BRANCH" ]; then
  LINE1="${LINE1} ${DIM}│${RESET} ${GREEN}🌿 ${BRANCH}${RESET}"
  [ -n "$GIT_STATS" ] && LINE1="${LINE1} ${YELLOW}${GIT_STATS}${RESET}"
fi
if [ -n "$STYLE" ] && [ "$STYLE" != "default" ] && [ "$STYLE" != "—" ]; then
  LINE1="${LINE1} ${DIM}│${RESET} ${YELLOW}💭 ${STYLE}${RESET}"
fi
echo -e "$LINE1"

# --- Line 2: model | context bar | 5h rate | 7d rate ---
RATE5_COLOR=$(rate_color "$RATE_5H")
RATE7_COLOR=$(rate_color "$RATE_7D")
echo -e "${BOLD}${CYAN}${MODEL}${RESET} ${DIM}│${RESET} ${BAR_COLOR}${BAR}${RESET} ${PCT}% ${DIM}[${CTX_LABEL}]${RESET} ${DIM}│${RESET} ${RATE5_COLOR}5h: ${RATE_5H}%${RESET} ${DIM}│${RESET} ${RATE7_COLOR}7d: ${RATE_7D}%${RESET}"

# --- Line 3: agent/worktree (only if active) ---
LINE3=""
[ -n "$AGENT" ] && LINE3="${CYAN}🤖 ${AGENT}${RESET}"
if [ -n "$WORKTREE" ]; then
  [ -n "$LINE3" ] && LINE3="${LINE3} ${DIM}│${RESET} "
  LINE3="${LINE3}${GREEN}🌳 ${WORKTREE}${RESET}"
  [ -n "$WT_BRANCH" ] && LINE3="${LINE3} ${DIM}(${WT_BRANCH})${RESET}"
fi
[ -n "$LINE3" ] && echo -e "$LINE3"

exit 0

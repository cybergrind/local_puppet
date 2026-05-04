#!/usr/bin/env bash
# Claude Code statusLine — single line
# Format: cwd (branch) | model | effort | session:N% (resets in T) | weekly:N%

input=$(cat)

cwd=$(echo "$input"        | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input"      | jq -r '.model.display_name // empty')
git_worktree=$(echo "$input" | jq -r '.workspace.git_worktree // empty')

ctx_pct=$(echo "$input"      | jq -r '.context_window.used_percentage // empty')
ctx_size=$(echo "$input"     | jq -r '.context_window.context_window_size // empty')
session_pct=$(echo "$input"   | jq -r '.rate_limits.five_hour.used_percentage // empty')
session_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
weekly_pct=$(echo "$input"    | jq -r '.rate_limits.seven_day.used_percentage // empty')
weekly_reset=$(echo "$input"  | jq -r '.rate_limits.seven_day.resets_at // empty')

effort=$(echo "$input" | jq -r '.effort.level // empty')

# Colors
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
RED="\033[31m"
GREY="\033[37m"
DIM="\033[2m"
RESET="\033[0m"

# Shorten cwd: replace $HOME with ~
short_cwd="${cwd/#$HOME/\~}"

# Git branch
git_branch=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --is-inside-work-tree --no-optional-locks >/dev/null 2>&1; then
    git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
        || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
    [ -n "$git_worktree" ] && git_branch="${git_branch}[wt:${git_worktree}]"
fi

# Strip date/version suffix from model name (e.g. "Claude Sonnet 4.6" -> "Sonnet 4.6")
model_short=$(echo "$model" | sed -E 's/^Claude //')

# Format a percentage as integer
fmt_pct() { [ -n "$1" ] && printf '%.0f' "$1"; }

# Format reset-time (unix epoch seconds OR ISO 8601) as a relative duration ("2h13m", "47m", "53s")
fmt_reset() {
    local v="$1"
    [ -z "$v" ] && return
    local target
    if [[ "$v" =~ ^[0-9]+$ ]]; then
        target=$v
    else
        target=$(date -d "$v" +%s 2>/dev/null) || return
    fi
    local now diff
    now=$(date +%s)
    diff=$(( target - now ))
    (( diff <= 0 )) && { printf 'now'; return; }
    local d=$(( diff / 86400 ))
    local h=$(( (diff % 86400) / 3600 ))
    local m=$(( (diff % 3600) / 60 ))
    local s=$(( diff % 60 ))
    if   (( d > 0 )); then printf '%dd%02dh' "$d" "$h"
    elif (( h > 0 )); then printf '%dh%02dm' "$h" "$m"
    elif (( m > 0 )); then printf '%dm' "$m"
    else                   printf '%ds' "$s"
    fi
}

# Color a percentage by severity
pct_color() {
    local p="$1"
    [ -z "$p" ] && { printf '%b' "$GREY"; return; }
    local i; i=$(printf '%.0f' "$p")
    if   (( i >= 90 )); then printf '%b' "$RED"
    elif (( i >= 70 )); then printf '%b' "$YELLOW"
    else                     printf '%b' "$GREEN"
    fi
}

# Build segments
parts=()

parts+=("${CYAN}${short_cwd}${RESET}")

if [ -n "$git_branch" ]; then
    parts+=("${GREEN}${git_branch}${RESET}")
fi

if [ -n "$model_short" ]; then
    parts+=("${BLUE}${model_short}${RESET}")
fi

if [ -n "$effort" ]; then
    parts+=("${MAGENTA}${effort}${RESET}")
fi

if [ -n "$ctx_pct" ] && [ -n "$ctx_size" ]; then
    cp=$(fmt_pct "$ctx_pct")
    cc=$(pct_color "$ctx_pct")
    used_k=$(( (cp * ctx_size) / 100 / 1000 ))
    limit_k=$(( ctx_size / 1000 ))
    parts+=("${DIM}ctx:${RESET}${cc}${used_k}k/${limit_k}k${RESET}${DIM}(${cp}%)${RESET}")
fi

if [ -n "$session_pct" ]; then
    sp=$(fmt_pct "$session_pct")
    sc=$(pct_color "$session_pct")
    sr=$(fmt_reset "$session_reset")
    if [ -n "$sr" ]; then
        parts+=("${DIM}session:${RESET}${sc}${sp}%${RESET}${DIM}(${sr})${RESET}")
    else
        parts+=("${DIM}session:${RESET}${sc}${sp}%${RESET}")
    fi
fi

if [ -n "$weekly_pct" ]; then
    wp=$(fmt_pct "$weekly_pct")
    wc=$(pct_color "$weekly_pct")
    wr=$(fmt_reset "$weekly_reset")
    if [ -n "$wr" ]; then
        parts+=("${DIM}weekly:${RESET}${wc}${wp}%${RESET}${DIM}(${wr})${RESET}")
    else
        parts+=("${DIM}weekly:${RESET}${wc}${wp}%${RESET}")
    fi
fi

# Join with " | "
SEP="${DIM} | ${RESET}"
out=""
for i in "${!parts[@]}"; do
    if [ "$i" -eq 0 ]; then
        out="${parts[$i]}"
    else
        out="${out}${SEP}${parts[$i]}"
    fi
done

printf '%b' "$out"

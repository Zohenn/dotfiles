#!/bin/sh
# Claude Code statusLine: model, git branch, context, rate limits.
# Reads the statusline JSON on stdin. Needs jq, git, awk. POSIX sh (Claude Code runs it via /bin/sh).
input=$(cat)
fmt() { awk -v n="$1" 'BEGIN { if (n >= 1000000) printf "%.1fM", n / 1e6; else if (n >= 1000) printf "%.0fk", n / 1e3; else printf "%d", n }'; }
until_reset() {
  s=$(( $1 - $(date +%s) ))
  [ "$s" -lt 0 ] && s=0
  d=$(( s / 86400 )); h=$(( s % 86400 / 3600 )); m=$(( s % 3600 / 60 ))
  if [ "$d" -gt 0 ]; then printf '%dd%dh' "$d" "$h"
  elif [ "$h" -gt 0 ]; then printf '%dh%dm' "$h" "$m"
  else printf '%dm' "$m"; fi
}
sep() { [ -n "$out" ] && printf ' \033[90m·\033[00m '; out=1; }
out=""

model=$(echo "$input" | jq -r '.model.display_name // empty')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // empty')
used=$(echo "$input" | jq -r '.context_window.current_usage | if . then (.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens) else empty end')
size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
ctx=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
h5=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
h5r=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
d7=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
d7r=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

[ -n "$model" ] && { sep; printf '\033[32m%s\033[00m' "$model"; }

if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  br=$(git -C "$cwd" branch --show-current 2>/dev/null)
  [ -z "$br" ] && br=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  dirty=""
  [ -n "$(git -C "$cwd" status --porcelain -uno 2>/dev/null)" ] && dirty="*"
  sep; printf '\033[34m%s%s\033[00m' "$br" "$dirty"
fi

if [ -n "$used" ] && [ -n "$size" ]; then
  sep; printf '\033[36mctx %s/%s (%s%%)\033[00m' "$(fmt "$used")" "$(fmt "$size")" "$ctx"
elif [ -n "$ctx" ]; then
  sep; printf '\033[36mctx (%s%%)\033[00m' "$ctx"
fi

if [ -n "$h5" ]; then
  sep; printf '\033[33m5h %s%%' "$h5"
  [ -n "$h5r" ] && printf ' ↻%s' "$(until_reset "$h5r")"
  printf '\033[00m'
fi
if [ -n "$d7" ]; then
  sep; printf '\033[35m7d %s%%' "$d7"
  [ -n "$d7r" ] && printf ' ↻%s' "$(until_reset "$d7r")"
  printf '\033[00m'
fi
exit 0

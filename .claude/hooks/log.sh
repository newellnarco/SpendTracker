#!/usr/bin/env bash
# Append an entry to the session log. Usage:
#   .claude/hooks/log.sh --session <sid> (start|progress|close) "text"   [--auto]
# `close` also marks the session closed so the prompt/stop hooks know the close-out happened.
set -u
. "$(dirname "$0")/lib.sh"
sid=""; auto=0; args=()
while [ $# -gt 0 ]; do case "$1" in --session) sid="$2"; shift 2;; --auto) auto=1; shift;; *) args+=("$1"); shift;; esac; done
[ -z "$sid" ] && sid="$(cat "$ST_STATE_DIR/current-session" 2>/dev/null || echo unknown)"
kind="${args[0]:-progress}"; text="${args[1]:-}"
case "$kind" in start|progress|close) ;; *) echo "kind must be start|progress|close" >&2; exit 1;; esac
[ -z "$text" ] && { echo "text required" >&2; exit 1; }
st_state_ensure "$sid" >/dev/null
model="$(st_state_get "$sid" model)"; role="$(st_role "$sid")"; n="$(st_state_get "$sid" prompts)"
[ "$(st_role_source "$sid")" = "prompt" ] && role="$role (declared)"
lfile="$ST_ROOT/$(st_policy '.session_log_file')"
mkdir -p "$(dirname "$lfile")"
[ -f "$lfile" ] || printf '# Session log\n\nAppend-only. Entries are written by `.claude/hooks/log.sh`; newest at the bottom.\n' > "$lfile"
{
  printf '\n## %s · %s · session `%s` · %s · %s · branch `%s` · prompts %s%s\n' "$(st_now)" "$kind" "$sid" "${model:-unknown}" "$role" "$(st_branch)" "${n:-0}" "$([ $auto = 1 ] && printf ' · auto')"
  printf '%s\n' "$text"
} >> "$lfile"
[ "$kind" = "close" ] && st_state_set "$sid" '.closed=true'
echo "logged $kind for $sid"

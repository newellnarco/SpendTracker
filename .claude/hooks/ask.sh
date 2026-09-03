#!/usr/bin/env bash
# File a question for the Fable session. Usage:
#   .claude/hooks/ask.sh --session <sid> "question text" [--context "why it matters / what is blocked"]
set -u
. "$(dirname "$0")/lib.sh"
sid=""; ctx=""; q=""
while [ $# -gt 0 ]; do case "$1" in --session) sid="$2"; shift 2;; --context) ctx="$2"; shift 2;; *) q="$1"; shift;; esac; done
[ -z "$sid" ] && sid="$(cat "$ST_STATE_DIR/current-session" 2>/dev/null || echo unknown)"
[ -z "$q" ] && { echo "question text required" >&2; exit 1; }
st_state_ensure "$sid" >/dev/null
model="$(st_state_get "$sid" model)"
qfile="$ST_ROOT/$(st_policy '.questions_file')"
[ -f "$qfile" ] || printf '# Questions log\n\nBuilder sessions append questions with `.claude/hooks/ask.sh`; only the Fable session answers (`answer.sh`).\nStatus values: pending · answered · needs-human.\n' > "$qfile"
id="Q-$(date -u +%Y%m%d)-$(head -c 2 /dev/urandom | od -An -tx1 | tr -d ' \n')"
pr="$(command -v gh >/dev/null 2>&1 && gh pr view --json number -q .number 2>/dev/null || true)"
{
  printf '\n### %s · pending\n' "$id"
  printf -- '- Status: pending\n'
  printf -- '- Asked: %s · session `%s` · model `%s` · branch `%s`%s\n' "$(st_now)" "$sid" "${model:-unknown}" "$(st_branch)" "${pr:+ · PR #$pr}"
  printf -- '- Question: %s\n' "$q"
  [ -n "$ctx" ] && printf -- '- Context: %s\n' "$ctx"
  printf -- '- Answer (Fable): _pending_\n'
} >> "$qfile"
echo "$id"

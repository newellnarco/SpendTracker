#!/usr/bin/env bash
# Record a known issue (from CI output or observed during a session). Any role may add; Fable curates.
# Usage:
#   .claude/hooks/issue.sh --session <sid> "title" [--check unit|integration|system|other]
#                          [--paths "a.py,b.py"] [--detail "error signature / repro"] [--status open|fixed|wontfix]
#                          [--ref "PR #n or commit"]
set -u
. "$(dirname "$0")/lib.sh"
sid=""; check="other"; paths=""; detail=""; status="open"; ref=""; title=""
while [ $# -gt 0 ]; do case "$1" in
  --session) sid="$2"; shift 2;; --check) check="$2"; shift 2;; --paths) paths="$2"; shift 2;;
  --detail) detail="$2"; shift 2;; --status) status="$2"; shift 2;; --ref) ref="$2"; shift 2;;
  *) title="$1"; shift;; esac; done
[ -z "$sid" ] && sid="$(cat "$ST_STATE_DIR/current-session" 2>/dev/null || echo unknown)"
[ -z "$title" ] && { echo "title required" >&2; exit 1; }
case "$status" in open|fixed|wontfix) ;; *) echo "status must be open|fixed|wontfix" >&2; exit 1;; esac
st_state_ensure "$sid" >/dev/null
model="$(st_state_get "$sid" model)"; role="$(st_role "$sid")"
ifile="$ST_ROOT/$(st_policy '.known_issues_file')"
[ -f "$ifile" ] || printf '# Known issues ledger\n\nEvery CI failure and observed defect gets an entry via `.claude/hooks/issue.sh`. Sessions read open entries at start so they are not reproduced. The Fable session keeps this file current (status, assignment, fix reference).\nStatus values: open · fixed · wontfix.\n' > "$ifile"
# Signature: stable hash of check + title so CI and sessions can detect duplicates.
sig="$(printf '%s|%s' "$check" "$title" | sha256sum | cut -c1-10)"
if grep -q "Signature: $sig" "$ifile"; then echo "duplicate of existing issue (signature $sig); update it instead" >&2; grep -B3 "Signature: $sig" "$ifile" | grep '^### ' | awk '{print $2}' | head -1; exit 0; fi
id="I-$(date -u +%Y%m%d)-$(head -c 2 /dev/urandom | od -An -tx1 | tr -d ' \n')"
{
  printf '\n### %s · %s · %s\n' "$id" "$status" "$check"
  printf -- '- Status: %s\n' "$status"
  printf -- '- Title: %s\n' "$title"
  printf -- '- Signature: %s\n' "$sig"
  printf -- '- Check: %s\n' "$check"
  [ -n "$paths" ] && printf -- '- Blast radius: %s\n' "$paths"
  [ -n "$detail" ] && printf -- '- Detail: %s\n' "$detail"
  [ -n "$ref" ] && printf -- '- Ref: %s\n' "$ref"
  printf -- '- Recorded: %s · session `%s` · model `%s` · %s · branch `%s`\n' "$(st_now)" "$sid" "${model:-unknown}" "$role" "$(st_branch)"
  printf -- '- Assigned: _unassigned_\n'
} >> "$ifile"
echo "$id"

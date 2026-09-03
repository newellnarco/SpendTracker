#!/usr/bin/env bash
# SessionEnd: if the session never ran its close-out, append an automatic entry so the next Fable
# session sees an unfinished session. Never blocks.
set -u
. "$(dirname "$0")/lib.sh"
input="$(cat)"
sid="$(printf '%s' "$input" | jq -r '.session_id // "unknown"')"
reason="$(printf '%s' "$input" | jq -r '.session_end_reason // .reason // "unknown"')"
[ -f "$(st_state_file "$sid")" ] || exit 0
closed="$(st_state_get "$sid" closed)"
if [ "$closed" != "true" ]; then
  "$(dirname "$0")/log.sh" --session "$sid" --auto close "Session ended (reason: $reason) WITHOUT a close-out. Progress and open questions may be unrecorded; Fable: inspect this session's branch and PR." >/dev/null 2>&1 || true
fi
exit 0

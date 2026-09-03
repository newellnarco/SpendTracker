#!/usr/bin/env bash
# Stop: at or past the prompt limit, refuse to end the turn until the close-out is logged.
# Exit 2 makes Claude continue with stderr as the instruction. stop_hook_active prevents loops.
set -u
. "$(dirname "$0")/lib.sh"
input="$(cat)"
sid="$(printf '%s' "$input" | jq -r '.session_id // "unknown"')"
active="$(printf '%s' "$input" | jq -r '.stop_hook_active // false')"
[ "$active" = "true" ] && exit 0
n="$(st_state_get "$sid" prompts)"; closed="$(st_state_get "$sid" closed)"; limit="$(st_policy '.prompt_limit')"
if [ -n "$n" ] && [ "$n" -ge "$limit" ] && [ "$closed" != "true" ]; then
  echo "Prompt limit reached and no close-out recorded for session $sid. Run .claude/hooks/log.sh --session $sid close \"<summary>\", file open questions with ask.sh, commit and push your branch, then stop." >&2
  exit 2
fi
exit 0

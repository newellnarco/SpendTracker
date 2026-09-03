#!/usr/bin/env bash
# PreModelSwitch: roles are declared, not inferred from the model (docs/PROCESS.md 1.1), so a switch
# cannot change what this session is allowed to do. Allow it and record the new model for the log.
set -u
. "$(dirname "$0")/lib.sh"
input="$(cat)"
sid="$(printf '%s' "$input" | jq -r '.session_id // "unknown"')"
model="$(printf '%s' "$input" | jq -r '.model // .to_model // empty')"
st_state_ensure "$sid" >/dev/null
[ -n "$model" ] && st_state_set "$sid" --arg m "$model" '.model=$m' 2>/dev/null || true
exit 0

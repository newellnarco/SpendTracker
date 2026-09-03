#!/usr/bin/env bash
# PreModelSwitch: a session's role is bound to the model it started with, or to its first declaration
# (ADR-0009). A switch would break that evidence, so switches are blocked: close out and start a new
# session with the other model.
set -u
. "$(dirname "$0")/lib.sh"
input="$(cat)"
sid="$(printf '%s' "$input" | jq -r '.session_id // "unknown"')"
role="$(st_role "$sid")"
echo "SpendTracker protocol: model switches are blocked; this session's role ($role) is bound to its starting model or first declaration (ADR-0009). Close out and start a new session with the other model." >&2
exit 2

#!/usr/bin/env bash
# UserPromptSubmit: pick up the session's role declaration, then count prompts per session; warn near
# the limit, force the close-out at the limit, block beyond it. Exit 2 blocks the prompt and shows
# stderr to the user.
set -u
. "$(dirname "$0")/lib.sh"
input="$(cat)"
sid="$(printf '%s' "$input" | jq -r '.session_id // "unknown"')"
st_state_ensure "$sid" >/dev/null
st_state_set "$sid" '.prompts = (.prompts // 0) + 1'
n="$(st_state_get "$sid" prompts)"; closed="$(st_state_get "$sid" closed)"
limit="$(st_policy '.prompt_limit')"; warn="$(st_policy '.warn_at')"

# Roles are declared, never inferred (docs/PROCESS.md 1.1). An undeclared session takes its role
# from the first "ROLE: fable" / "ROLE: builder" it is given; a declared role is never overwritten,
# so a later prompt cannot promote a builder.
role="$(st_role "$sid")"
if [ "$role" = "undeclared" ]; then
  declared="$(st_role_from_text "$(printf '%s' "$input" | jq -r '.prompt // empty')")"
  if st_role_valid "$declared"; then
    st_state_set "$sid" --arg r "$declared" '.role=$r'
    role="$declared"
  fi
fi

if [ "$closed" = "true" ]; then
  echo "SpendTracker protocol: this session already ran its close-out. Start a new session." >&2
  exit 2
fi
if [ "$n" -gt "$limit" ]; then
  echo "SpendTracker protocol: prompt limit ($limit) reached and no close-out recorded. Run: .claude/hooks/log.sh --session $sid close \"summary\" (and ask.sh for open questions), then start a new session." >&2
  exit 2
fi
if [ "$n" -eq "$limit" ]; then
  st_context "UserPromptSubmit" "PROTOCOL: this is prompt $n of $limit, the last one. Before anything else, run the close-out (/close-out): log.sh close, ask.sh for every open question, push, ensure the PR exists. Then stop."
fi
if [ "$n" -ge "$warn" ]; then
  st_context "UserPromptSubmit" "PROTOCOL: prompt $n of $limit. Plan to finish and run /close-out before prompt $limit."
fi
if [ "$role" = "undeclared" ]; then
  st_context "UserPromptSubmit" "PROTOCOL: this session has no declared role, so it may not merge, push to a protected branch or write the ledger files. Per docs/PROCESS.md 1.1, ask which role this session is running as before doing anything else; the reply must state ROLE: fable or ROLE: builder verbatim."
fi
exit 0

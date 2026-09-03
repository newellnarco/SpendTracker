#!/usr/bin/env bash
# UserPromptSubmit: pick up a role declaration when the session is undeclared (ADR-0009), then count
# prompts per session; warn near the limit, force the close-out at the limit, block beyond it.
# Exit 2 blocks the prompt and shows stderr to the user.
set -u
. "$(dirname "$0")/lib.sh"
input="$(cat)"
sid="$(printf '%s' "$input" | jq -r '.session_id // "unknown"')"
st_state_ensure "$sid" >/dev/null
st_state_set "$sid" '.prompts = (.prompts // 0) + 1'
n="$(st_state_get "$sid" prompts)"; closed="$(st_state_get "$sid" closed)"
limit="$(st_policy '.prompt_limit')"; warn="$(st_policy '.warn_at')"

# An undeclared session takes its role from the first "ROLE: fable|builder" it is given. A role that
# was observed from the model or set by the owner is never changed by a prompt, so a prompt cannot
# promote a builder to Fable.
role="$(st_role "$sid")"; src="$(st_role_source "$sid")"
declared="$(st_role_from_text "$(printf '%s' "$input" | jq -r '.prompt // empty')")"
notice=""
if st_role_valid "$declared"; then
  if [ "$role" = "undeclared" ]; then
    st_state_set "$sid" --arg r "$declared" '.role=$r | .role_source="prompt"'
    role="$declared"; src="prompt"
    notice="PROTOCOL: role declared as $declared for the rest of this session (ADR-0009)."
    [ "$declared" = "fable" ] && notice="$notice Confirm the model with get_session and record it in your first log.sh entry; the declaration is self-reported."
  elif [ "$declared" != "$role" ]; then
    notice="PROTOCOL: the declaration ROLE: $declared was ignored; this session's role is $role (source: $src) and cannot change. Close out and start a new session for the other role."
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
msg="$notice"
if [ "$n" -eq "$limit" ]; then
  msg="${msg:+$msg
}PROTOCOL: this is prompt $n of $limit, the last one. Before anything else, run the close-out (/close-out): log.sh close, ask.sh for every open question, push, ensure the PR exists. Then stop."
elif [ "$n" -ge "$warn" ]; then
  msg="${msg:+$msg
}PROTOCOL: prompt $n of $limit. Plan to finish and run /close-out before prompt $limit."
fi
if [ "$role" = "undeclared" ]; then
  msg="${msg:+$msg
}PROTOCOL: this session has no role, so it may not merge, push to a protected branch or write the ledger files. Establish the role first (get_session, or ask the owner); the declaration must state ROLE: fable or ROLE: builder verbatim (ADR-0009)."
fi
[ -n "$msg" ] && st_context "UserPromptSubmit" "$msg"
exit 0

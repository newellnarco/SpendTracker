#!/usr/bin/env bash
# Shared helpers for SpendTracker session-protocol hooks. Sourced, not executed.
# Requires: bash 4+, jq, git.
ST_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
ST_POLICY="$ST_ROOT/.claude/hooks/policy.json"
ST_STATE_DIR="$ST_ROOT/.claude/state/sessions"
mkdir -p "$ST_STATE_DIR" 2>/dev/null || true

st_policy() { jq -r "$1" "$ST_POLICY" 2>/dev/null; }
st_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
st_branch() { git -C "$ST_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown"; }

# Roles are declared, never inferred from the model (docs/PROCESS.md §1.1): a session cannot
# reliably tell which model it runs on, and the serving model can change mid-session.
st_role_valid() { case "${1:-}" in fable|builder) return 0;; *) return 1;; esac; }

# The role declared for a new session: SPENDTRACKER_ROLE when set and valid, else undeclared.
# An undeclared session is resolved later from its opening prompt (prompt-submit.sh).
st_role_declared() {
  local r="${SPENDTRACKER_ROLE:-}"
  if st_role_valid "$r"; then printf '%s' "$r"; else printf 'undeclared'; fi
}

# First "ROLE: fable" / "ROLE: builder" declaration in a block of text; empty when absent.
st_role_from_text() {
  printf '%s' "${1:-}" \
    | grep -Eio 'ROLE[[:space:]]*:[[:space:]]*(fable|builder)' \
    | head -1 | sed -E 's/.*:[[:space:]]*//' | tr '[:upper:]' '[:lower:]'
}

st_state_file() { printf '%s/%s.json' "$ST_STATE_DIR" "$1"; }

# Read a field from the session state; empty if unknown.
st_state_get() { # sid field
  local f; f="$(st_state_file "$1")"
  [ -f "$f" ] && jq -r ".$2 // empty" "$f" 2>/dev/null
}

# Create state if missing. A session with no declaration starts undeclared and is restricted
# until it declares; see st_role and pre-tool.sh.
st_state_ensure() { # sid [model]
  local f; f="$(st_state_file "$1")"
  if [ ! -f "$f" ]; then
    local model="${2:-unknown}" role
    role="$(st_role_declared)"
    jq -n --arg sid "$1" --arg model "$model" --arg role "$role" --arg now "$(st_now)" --arg br "$(st_branch)" \
      '{session_id:$sid, model:$model, role:$role, prompts:0, started_at:$now, branch:$br, closed:false}' > "$f"
  fi
  printf '%s' "$f"
}

st_state_set() { # sid [jq options...] jq-assignment (e.g. '.closed=true', or --arg r x '.role=$r')
  local f tmp; f="$(st_state_ensure "$1")"; shift; tmp="$f.tmp"
  jq "$@" "$f" > "$tmp" && mv "$tmp" "$f"
}

st_role() { # sid -> fable | builder | undeclared (undeclared when unknown: fail closed)
  local r; r="$(st_state_get "$1" role)"
  st_role_valid "$r" && printf '%s' "$r" || printf 'undeclared'
}

# Emit a PreToolUse deny decision and exit 0.
st_deny() { # reason
  jq -n --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

# Emit additionalContext for the given event and exit 0.
st_context() { # event text
  jq -n --arg e "$1" --arg t "$2" '{hookSpecificOutput:{hookEventName:$e,additionalContext:$t}}'
  exit 0
}

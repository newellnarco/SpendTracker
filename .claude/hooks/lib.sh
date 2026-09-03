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

# Role from a model id. Env SPENDTRACKER_ROLE overrides (fable|builder).
st_role_for_model() {
  local model="$1" pat
  if [ -n "${SPENDTRACKER_ROLE:-}" ]; then printf '%s' "$SPENDTRACKER_ROLE"; return; fi
  pat="$(st_policy '.fable_model_pattern')"
  if printf '%s' "$model" | grep -Eiq "$pat"; then printf 'fable'; else printf 'builder'; fi
}

st_state_file() { printf '%s/%s.json' "$ST_STATE_DIR" "$1"; }

# Read a field from the session state; empty if unknown.
st_state_get() { # sid field
  local f; f="$(st_state_file "$1")"
  [ -f "$f" ] && jq -r ".$2 // empty" "$f" 2>/dev/null
}

# Create state if missing (sessions that started before the hooks existed default to builder).
st_state_ensure() { # sid [model]
  local f; f="$(st_state_file "$1")"
  if [ ! -f "$f" ]; then
    local model="${2:-unknown}" role
    role="$(st_role_for_model "$model")"
    jq -n --arg sid "$1" --arg model "$model" --arg role "$role" --arg now "$(st_now)" --arg br "$(st_branch)" \
      '{session_id:$sid, model:$model, role:$role, prompts:0, started_at:$now, branch:$br, closed:false}' > "$f"
  fi
  printf '%s' "$f"
}

st_state_set() { # sid jq-assignment (e.g. '.closed=true')
  local f tmp; f="$(st_state_ensure "$1")"; tmp="$f.tmp"
  jq "$2" "$f" > "$tmp" && mv "$tmp" "$f"
}

st_role() { # sid -> role (builder when unknown)
  local r; r="$(st_state_get "$1" role)"; printf '%s' "${r:-builder}"
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

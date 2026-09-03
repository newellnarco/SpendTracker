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

st_role_valid() { case "${1:-}" in fable|builder) return 0;; *) return 1;; esac; }

# Role determination (ADR-0009), in precedence order. Prints "<role> <source>".
#   1. SPENDTRACKER_ROLE in the process environment (owner override)              -> source env
#   2. the model the platform reported at SessionStart, matched against
#      fable_model_pattern in policy.json                                          -> source model
#   3. no model reported: undeclared until the first "ROLE: fable|builder" prompt   -> source prompt
# An undeclared session fails closed: every builder restriction applies (pre-tool.sh).
st_role_for_model() { # model
  local model="${1:-}" pat
  if st_role_valid "${SPENDTRACKER_ROLE:-}"; then printf '%s env' "$SPENDTRACKER_ROLE"; return; fi
  case "$model" in ""|unknown|null) printf 'undeclared none'; return;; esac
  pat="$(st_policy '.fable_model_pattern')"
  if printf '%s' "$model" | grep -Eiq "$pat"; then printf 'fable model'; else printf 'builder model'; fi
}

# First "ROLE: fable" / "ROLE: builder" declaration in a block of text; empty when absent.
st_role_from_text() {
  printf '%s' "${1:-}" | grep -Eio 'ROLE[[:space:]]*:[[:space:]]*(fable|builder)' \
    | head -1 | sed -E 's/.*:[[:space:]]*//' | tr '[:upper:]' '[:lower:]'
}

st_state_file() { printf '%s/%s.json' "$ST_STATE_DIR" "$1"; }

# Read a field from the session state; empty if unknown.
st_state_get() { # sid field
  local f; f="$(st_state_file "$1")"
  [ -f "$f" ] && jq -r ".$2 // empty" "$f" 2>/dev/null
}

# Create state if missing. The role comes from st_role_for_model; with no model it is undeclared.
st_state_ensure() { # sid [model]
  local f; f="$(st_state_file "$1")"
  if [ ! -f "$f" ]; then
    local model="${2:-unknown}" role src
    read -r role src <<<"$(st_role_for_model "$model")"
    jq -n --arg sid "$1" --arg model "$model" --arg role "$role" --arg src "$src" --arg now "$(st_now)" --arg br "$(st_branch)" \
      '{session_id:$sid, model:$model, role:$role, role_source:$src, prompts:0, started_at:$now, branch:$br, closed:false}' > "$f"
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
st_role_source() { local s; s="$(st_state_get "$1" role_source)"; printf '%s' "${s:-none}"; }

# Resolve the builder session queue entry for a branch (ADR-0010): the entry marked `in progress`
# whose Branch line names the branch, otherwise the first entry with status `open`. Prints the id.
st_queue_entry() { # context-file branch
  awk -v br="$2" '
    /^### BS-/ { n=split($0, a, " · "); id=substr(a[1], 5); st=a[2]; ids[++k]=id; status[id]=st }
    /^- Branch:/ && id != "" { if (match($0, /`[^`]+`/)) branch[id]=substr($0, RSTART+1, RLENGTH-2) }
    END {
      for (i=1; i<=k; i++) if (status[ids[i]]=="in progress" && branch[ids[i]]==br) { print ids[i]; exit }
      for (i=1; i<=k; i++) if (status[ids[i]]=="open") { print ids[i]; exit }
    }' "$1" 2>/dev/null
}
# The text of one queue entry: from its header to the next heading.
st_queue_entry_text() { # context-file id
  awk -v id="$2" '/^### /{p=($2==id)} /^## /{p=0} p' "$1" 2>/dev/null
}
# The packet path for an entry: the entry's "- Packet:" line, else docs/tasks/<id>-*.md.
st_packet_for() { # context-file id
  local p; p="$(st_queue_entry_text "$1" "$2" | awk '/^- Packet:/ && match($0, /`[^`]+`/) {print substr($0, RSTART+1, RLENGTH-2); exit}')"
  [ -z "$p" ] && p="$(cd "$ST_ROOT" 2>/dev/null && ls "$(st_policy '.packet_dir')$2"-*.md 2>/dev/null | head -1)"
  printf '%s' "$p"
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

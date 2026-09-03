#!/usr/bin/env bash
# SpendTracker hook for Claude Code. Reads the hook JSON on stdin, writes ONE spool envelope, exits 0.
# Contract: never block, never open the database, never read prompt or tool content, finish in < 50 ms.
# Requires: jq. Installed by `st hooks install` to ~/.spendtracker/hooks/.
set -u
SPOOL="${SPENDTRACKER_SPOOL:-$HOME/.spendtracker/spool}"
mkdir -p "$SPOOL" 2>/dev/null || exit 0

input="$(cat)"
event="$(printf '%s' "$input" | jq -r '.hook_event_name // empty')"
[ -z "$event" ] && exit 0

# Fast, sortable id: epoch-millis + random. The ingester assigns the real ULID.
id="$(date +%s%3N 2>/dev/null || python3 -c 'import time;print(int(time.time()*1000))')-$RANDOM"
now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
tmp="$SPOOL/.$id.json.tmp"
out="$SPOOL/$id.json"

# Project key from cwd: normalized git remote if available, else a hash of the path. Cheap: git config read only.
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
project_key=""
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
  remote="$(git -C "$cwd" config --get remote.origin.url 2>/dev/null || true)"
  if [ -n "$remote" ]; then
    project_key="$(printf '%s' "$remote" | sed -E 's#^(git@|https?://)##; s#:#/#; s#\.git$##; s#^www\.##')"
  else
    project_key="path:$(printf '%s' "$cwd" | shasum -a 256 2>/dev/null | cut -c1-16)"
  fi
fi

# Build the envelope. Only ids, counts and timestamps leave this script.
printf '%s' "$input" | jq -c \
  --arg now "$now" --arg project_key "$project_key" --arg event "$event" '
  def base: {
    v: 1, adapter: "claude_code", app: "claude_code", source: "hook",
    occurred_at: $now, project_key: $project_key,
    session_key: (.session_id // null),
    attrs: { hook_event: $event, agent_id: (.agent_id // null), permission_mode: (.permission_mode // null) }
  };
  if $event == "SessionStart" then
    base + { measure: "session.count", quantity: 1,
             source_ref: ("session:" + (.session_id // "unknown")),
             model: (.model // null),
             attrs: (base.attrs + { start_reason: (.session_start_reason // null) }) }
  elif $event == "PostToolUse" and ((.tool_name // "") | startswith("mcp__")) then
    ( (.tool_name | split("__")) as $p |
      base + { measure: "mcp.tool_call", quantity: 1,
               source_ref: ("tool:" + (.tool_use_id // "unknown")),
               tool_name: ($p[2:] | join("__")), mcp_server: $p[1],
               attrs: (base.attrs + { duration_ms: (.execution_time_ms // null) }) } )
  elif $event == "Stop" then
    base + { measure: "turn.count", quantity: 1,
             source_ref: ("turn:" + (.session_id // "unknown") + ":" + ((.turn_number // 0) | tostring)),
             attrs: (base.attrs + { stop_reason: (.stop_reason // null) }) }
  elif $event == "SessionEnd" then
    base + { measure: "session.end", quantity: 1,
             source_ref: ("session_end:" + (.session_id // "unknown")),
             attrs: (base.attrs + { end_reason: (.session_end_reason // null),
                                    turn_count: (.turn_count // null),
                                    transcript_path: (.transcript_path // null) }) }
  else empty end
' > "$tmp" 2>/dev/null && [ -s "$tmp" ] && mv "$tmp" "$out"
rm -f "$tmp" 2>/dev/null

# On SessionEnd, ask the ingester to parse the transcript for token counts (background, detached).
if [ "$event" = "SessionEnd" ] && command -v st >/dev/null 2>&1; then
  tp="$(printf '%s' "$input" | jq -r '.transcript_path // empty')"
  sid="$(printf '%s' "$input" | jq -r '.session_id // empty')"
  [ -n "$tp" ] && ( nohup st ingest --transcript "$tp" --session "$sid" >/dev/null 2>&1 & )
fi
exit 0

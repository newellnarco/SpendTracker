#!/usr/bin/env bash
# SessionStart: record the session's model and role, then inject the context that role needs.
# Role: from the reported model when the platform gives one, else undeclared until a prompt states
# ROLE: fable|builder (ADR-0009). Fable sessions get the full ledger context; builder sessions get
# only their packet's context (ADR-0010); undeclared sessions get a brief telling them to declare.
set -u
. "$(dirname "$0")/lib.sh"
input="$(cat)"
sid="$(printf '%s' "$input" | jq -r '.session_id // "unknown"')"
model="$(printf '%s' "$input" | jq -r '.model // empty')"
source_="$(printf '%s' "$input" | jq -r '.source // .session_start_reason // "startup"')"
[ -z "$model" ] && model="${CLAUDE_MODEL:-unknown}"

f="$(st_state_ensure "$sid" "$model")"
# A fresh start records the model and role; resume/compact keep the role and the prompt count.
case "$source_" in
  startup|clear|fork)
    read -r role src <<<"$(st_role_for_model "$model")"
    st_state_set "$sid" --arg m "$model" --arg r "$role" --arg s "$src" '.model=$m | .role=$r | .role_source=$s' ;;
esac
role="$(st_role "$sid")"; src="$(st_role_source "$sid")"
limit="$(st_policy '.prompt_limit')"; qfile="$(st_policy '.questions_file')"; lfile="$(st_policy '.session_log_file')"; cfile="$(st_policy '.context_file')"
ifile="$(st_policy '.known_issues_file')"
branch="$(st_branch)"
printf '%s' "$sid" > "$ST_STATE_DIR/current-session" 2>/dev/null || true

entry=""; packet=""
if [ "$role" = "builder" ] && [ -f "$ST_ROOT/$cfile" ]; then
  entry="$(st_queue_entry "$ST_ROOT/$cfile" "$branch")"
  [ -n "$entry" ] && packet="$(st_packet_for "$ST_ROOT/$cfile" "$entry")"
  st_state_set "$sid" --arg e "$entry" --arg p "$packet" '.entry=$e | .packet=$p'
fi

section() { printf '\n## %s\n' "$1"; }
ctx="$(
  printf '# SpendTracker session protocol\n'
  printf 'Session id: `%s` · model: `%s` · role: **%s** (source: %s) · branch: `%s` · prompt limit: %s\n' "$sid" "$model" "$role" "$src" "$branch" "$limit"
  printf 'Full rules: docs/02-delivery/SESSION-PROTOCOL.md. Helpers: .claude/hooks/ask.sh, log.sh, issue.sh; answer.sh (Fable only).\n'

  section "Your role"
  if [ "$role" = "undeclared" ]; then
    cat <<'TXT'
This session has NOT been given a role: the platform reported no model at start, so the hooks could
not bind one (ADR-0009). It is restricted until a role is declared: it may read and build, but it
may not merge, push to a protected branch, or write the ledger files.

Before doing anything else, establish the role: if the session tooling can report the model
(cloud sessions: `get_session`, field session_context.model), state the matching role verbatim as
`ROLE: fable` (model matches fable|mythos) or `ROLE: builder` (any other model), and say in your
first log.sh entry that the role was declared from get_session. Otherwise ask the owner, whose
reply must state `ROLE: fable` or `ROLE: builder`. The first declaration binds for the whole session.
TXT
  elif [ "$role" = "fable" ]; then
    [ "$src" = "prompt" ] && printf 'Your role was DECLARED in a prompt, not observed from the model. Confirm the model with get_session and record it in your start log entry before answering, curating or merging.\n\n'
    cat <<'TXT'
You are the FABLE session. You hold the full context and you do not build. You:
1. Read docs/00-context/CONTEXT.md, then the open questions and session log below.
2. Answer every pending question in docs/00-context/QUESTIONS.md using `.claude/hooks/answer.sh --session <sid> Q-id "answer"` (status answered or needs-human).
3. Review progress: open PRs from builder sessions, their diffs, and their session-log entries. Bring docs/00-context/KNOWN-ISSUES.md up to date from each PR's CI issue output (issue.sh to add, edit to assign or mark fixed).
4. For each PR: confirm the author is the owner's GitHub username; run the packet's acceptance criteria on the PR head; confirm CI ran and passed unit, integration and system checks covering the change's blast radius on the head commit (GitHub MCP tools: pull_request_read get_check_runs). Merge only when green, author-compliant, criteria met, every question answered and every failure recorded. Do not merge otherwise; write why in the session log.
5. Update CONTEXT.md (current state, decisions, open questions, builder session queue, phase history) and write or refresh the task packet in docs/tasks/ for the next open queue entry; commit to main, push.
6. Close with `.claude/hooks/log.sh --session <sid> close "summary"` and stop.
Run /fable-review to follow this as a checklist. Edits outside docs/, .claude/, README.md, CHANGELOG.md, schema/seed/ are denied by policy.
TXT
  else
    cat <<'TXT'
You are a BUILDER session. You execute one task packet end to end on your own branch and draft PR, then stop.
Your context is deliberately narrow (ADR-0010): docs/PROCESS.md, your packet, the documents the packet lists, and what this brief injects (current state, your queue entry, open known issues, questions answered on this branch, your own earlier log entries). Do not read other packets, other branches' work, the decisions log or the rest of CONTEXT.md; the hooks deny other packets. If you need something outside your packet, ask for it with ask.sh rather than going looking.
1. Read docs/PROCESS.md, then your packet (path below), then the packet's reading list in its order. Do not start from the code.
2. Your entry is the one shown below: the entry `in progress` on this branch if you are resuming (continue from the first unmet checkpoint), otherwise the first `open` entry. If the user gave you a task instead, run it the same way. Do the whole entry: goal, scope, acceptance criteria. Do not start a second entry.
3. Act on everything Fable left for you: fix the known issues the entry lists under "Fix issues" (and any open issue assigned to your branch); apply the answers under "Act on answers" and every QUESTIONS.md entry on this branch with Status: answered (an answer is an instruction); make every change under "Changes requested by Fable", updating the design docs first when the change is architectural (PHASE-PLAYBOOK step 4).
4. Ask questions with `.claude/hooks/ask.sh --session <sid> "question" --context "what depends on it"` (never edit QUESTIONS.md directly). Do not answer questions; only the Fable session answers. If the answer blocks the entry, log it, close out, and stop.
5. Record progress with `.claude/hooks/log.sh --session <sid> progress "BS-nnn: text"` at every checkpoint; record every defect or CI failure with `.claude/hooks/issue.sh` so it is never reproduced. Fix open known issues only when they are assigned to your entry or branch.
6. You may not merge, push to main, or edit CONTEXT.md or the ledgers directly; policy denies these. Push to the branch this session was started on (cloud sessions: the `claude/...` branch the harness assigned; local sessions: the branch the packet names). PRs are opened under the owner's GitHub username only, as drafts.
7. Before your last prompt (limit above), run /close-out: log a close entry naming the entry id and whether each acceptance criterion is met, file open questions and issues, push, ensure the draft PR exists, then stop.
TXT
  fi

  if [ "$role" = "builder" ]; then
    section "Current state (from CONTEXT.md)"
    if [ -f "$ST_ROOT/$cfile" ]; then awk '/^## Current state/{p=1} /^## Next actions/{p=0} p' "$ST_ROOT/$cfile" | head -40; else printf '(missing)\n'; fi
    section "Your queue entry"
    if [ -n "$entry" ]; then
      printf 'Entry: %s · packet: %s\n\n' "$entry" "${packet:-(no packet file; the entry below is the whole specification)}"
      st_queue_entry_text "$ST_ROOT/$cfile" "$entry"
    else
      printf '(no open or in-progress entry found in CONTEXT.md; ask the owner or the Fable session for a task)\n'
    fi
  elif [ "$role" = "fable" ]; then
    section "CONTEXT.md — current state, next actions and builder session queue"
    if [ -f "$ST_ROOT/$cfile" ]; then awk '/^## Current state/{p=1} /^## Decisions log/{p=0} p' "$ST_ROOT/$cfile" | head -160; else printf '(missing)\n'; fi
  else
    section "Current state (from CONTEXT.md)"
    if [ -f "$ST_ROOT/$cfile" ]; then awk '/^## Current state/{p=1} /^## Next actions/{p=0} p' "$ST_ROOT/$cfile" | head -40; fi
  fi

  if [ "$role" != "undeclared" ]; then
    section "Open known issues (do not reproduce; fix only if assigned to you)"
    if [ -f "$ST_ROOT/$ifile" ]; then
      awk '/^### I-/{h=$0} /^- Blast radius:/{br=$0} /^- Assigned:/{if (h ~ / open /) print h "  " br "  " $0; h=""; br=""}' "$ST_ROOT/$ifile" | head -40
    fi
    section "Answered questions on this branch (act on the answers)"
    if [ -f "$ST_ROOT/$qfile" ]; then
      awk '/^### Q-/{h=$0} /^- Status: answered/{a=1} /^- Answer \(Fable\):/{if (a) print h "\n  " $0; a=0}' "$ST_ROOT/$qfile" | tail -40
    fi
    section "Pending questions on this branch"
    if [ -f "$ST_ROOT/$qfile" ]; then
      awk '/^### Q-/{h=$0} /^- Status: pending/{print h} /^- Status: needs-human/{print h " (needs human)"}' "$ST_ROOT/$qfile" | head -40
    fi
  fi

  if [ "$role" = "fable" ]; then
    section "Pending questions on other branches (scanned from origin)"
    if timeout 25 git -C "$ST_ROOT" fetch --quiet --all --prune 2>/dev/null; then
      for b in $(git -C "$ST_ROOT" for-each-ref --format='%(refname:short)' refs/remotes/origin/ 2>/dev/null | grep -Ev '/(HEAD|main|master)$'); do
        git -C "$ST_ROOT" show "$b:$qfile" 2>/dev/null | awk -v b="$b" '/^### Q-/{h=$0} /^- Status: pending/{print b ": " h}'
      done | head -40
    else
      printf '(fetch unavailable; scan skipped)\n'
    fi
    section "Open branches and PRs"
    git -C "$ST_ROOT" for-each-ref --sort=-committerdate --format='%(refname:short) %(committerdate:short) %(subject)' refs/remotes/origin/ 2>/dev/null | grep -Ev '/HEAD' | head -15
    if command -v gh >/dev/null 2>&1; then timeout 20 gh pr list --state open --limit 20 2>/dev/null || true
    else printf '(gh not available: use the GitHub MCP tools list_pull_requests / pull_request_read)\n'; fi
    section "Last session-log entries"
    if [ -f "$ST_ROOT/$lfile" ]; then awk '/^## /{n++} n>0' "$ST_ROOT/$lfile" | tail -60; fi
  elif [ "$role" = "builder" ]; then
    section "Your earlier log entries on this branch"
    if [ -f "$ST_ROOT/$lfile" ]; then
      awk -v br="$branch" '/^## /{p=index($0, "branch `" br "`")>0} p' "$ST_ROOT/$lfile" | tail -30
    fi
  fi
)"
# Keep the injected context bounded.
ctx="$(printf '%s' "$ctx" | head -c 24000)"
st_context "SessionStart" "$ctx"

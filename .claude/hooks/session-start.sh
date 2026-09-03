#!/usr/bin/env bash
# SessionStart: record the session's model and role, then inject the project context the role needs.
# Fable sessions get the review/answer/merge brief; builder sessions get the build/ask/close-out brief.
set -u
. "$(dirname "$0")/lib.sh"
input="$(cat)"
sid="$(printf '%s' "$input" | jq -r '.session_id // "unknown"')"
model="$(printf '%s' "$input" | jq -r '.model // empty')"
source_="$(printf '%s' "$input" | jq -r '.source // .session_start_reason // "startup"')"
[ -z "$model" ] && model="${CLAUDE_MODEL:-unknown}"

f="$(st_state_ensure "$sid" "$model")"
# A fresh start records the model; resume/compact keep the prompt count.
case "$source_" in
  startup|clear|fork) st_state_set "$sid" --arg m "$model" --arg r "$(st_role_for_model "$model")" '.model=$m | .role=$r' 2>/dev/null \
     || { tmp="$f.tmp"; jq --arg m "$model" --arg r "$(st_role_for_model "$model")" '.model=$m | .role=$r' "$f" > "$tmp" && mv "$tmp" "$f"; } ;;
esac
role="$(st_role "$sid")"
limit="$(st_policy '.prompt_limit')"; qfile="$(st_policy '.questions_file')"; lfile="$(st_policy '.session_log_file')"; cfile="$(st_policy '.context_file')"
branch="$(st_branch)"
printf '%s' "$sid" > "$ST_STATE_DIR/current-session" 2>/dev/null || true

section() { printf '\n## %s\n' "$1"; }
ctx="$(
  printf '# SpendTracker session protocol\n'
  printf 'Session id: `%s` · model: `%s` · role: **%s** · branch: `%s` · prompt limit: %s\n' "$sid" "$model" "$role" "$branch" "$limit"
  printf 'Full rules: docs/02-delivery/SESSION-PROTOCOL.md. Helpers: .claude/hooks/ask.sh, log.sh, answer.sh (Fable only).\n'

  section "Your role"
  if [ "$role" = "fable" ]; then
    cat <<'TXT'
You are the FABLE session. You do not build. You:
1. Read docs/00-context/CONTEXT.md, then the open questions and session log below.
2. Answer every pending question in docs/00-context/QUESTIONS.md using `.claude/hooks/answer.sh --session <sid> Q-id "answer"` (status answered or needs-human).
3. Review progress: open PRs from builder sessions, their diffs, and their session-log entries. Bring docs/00-context/KNOWN-ISSUES.md up to date from each PR's CI issue output (issue.sh to add, edit to assign or mark fixed).
4. For each PR: confirm the author is the owner's GitHub username, and that CI ran and passed unit, integration and system checks covering the change's blast radius on the head commit (GitHub MCP tools: pull_request_read get_check_runs). Merge only when green, author-compliant, every question answered and every failure recorded. Do not merge otherwise; write why in the session log.
5. Update CONTEXT.md (current state, decisions, open questions, phase history), commit to main, push.
6. Close with `.claude/hooks/log.sh --session <sid> close "summary"` and stop.
Run /fable-review to follow this as a checklist. Edits outside docs/, .claude/, README.md, schema/seed/ are denied by policy.
TXT
  else
    cat <<'TXT'
You are a BUILDER session. You execute one end-to-end piece of work that the Fable session specified, on its own branch and PR, then stop. You:
1. Read all context and design before touching code: docs/00-context/CONTEXT.md in full; the reading order in docs/README.md; the active slice in docs/02-delivery/VERTICAL-SLICES.md; docs/02-delivery/PHASE-PLAYBOOK.md; every document your queue entry lists under "Read"; the ADRs it cites.
2. Pick up your session from the "Builder session queue" in CONTEXT.md: the entry marked `in progress` for your branch if you are resuming (check the branch out from origin and continue), otherwise the first `open` entry that is not `blocked`. If the user gave you a task instead, run it the same way. Do the whole entry: goal, scope, exit criteria. Do not start a second entry.
3. Act on everything Fable left for you: fix the known issues the entry lists under "Fix issues" (and any open issue assigned to your branch); apply the answers under "Act on answers" and every QUESTIONS.md entry on this branch with Status: answered (an answer is an instruction); make every architecture or code change under "Changes requested by Fable", updating the design docs first when the change is architectural (PHASE-PLAYBOOK step 4).
4. Ask questions with `.claude/hooks/ask.sh --session <sid> "question"` (never edit QUESTIONS.md directly). Do not answer questions; only the Fable session answers. If the answer blocks the entry, log it, close out, and stop.
5. Record progress with `.claude/hooks/log.sh --session <sid> progress "BS-nnn: text"`; record every defect or CI failure with `.claude/hooks/issue.sh` so it is never reproduced. Fix open known issues only when they are assigned to your entry or branch.
6. You may not merge, push to main, or edit CONTEXT.md or the ledgers directly; policy denies these. PRs are opened under the owner's GitHub username only, as drafts.
7. Before your last prompt (limit above), run /close-out: log a close entry naming the entry id and whether its exit criteria are met, file open questions and issues, push, ensure the draft PR exists, then stop.
TXT
  fi

  section "CONTEXT.md — current state, next actions and builder session queue"
  if [ -f "$ST_ROOT/$cfile" ]; then
    awk '/^## Current state/{p=1} /^## Decisions log/{p=0} p' "$ST_ROOT/$cfile" | head -160
  else printf '(missing)\n'; fi

  section "Open known issues (do not reproduce; fix only if assigned to you)"
  ifile="$(st_policy '.known_issues_file')"
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
  if [ -f "$ST_ROOT/$lfile" ]; then
    awk '/^## /{n++} n>0' "$ST_ROOT/$lfile" | tail -60
  fi
)"
# Keep the injected context bounded.
ctx="$(printf '%s' "$ctx" | head -c 24000)"
st_context "SessionStart" "$ctx"

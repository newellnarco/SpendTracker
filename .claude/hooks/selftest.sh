#!/usr/bin/env bash
# Self-test for the session-protocol hooks. Runs against a scratch copy of the repo so no live
# ledger or state is touched. Usage: .claude/hooks/selftest.sh   (exit 0 when every check passes)
set -u
SRC="$(cd "$(dirname "$0")/../.." && pwd)"
W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT
mkdir -p "$W"; cp -r "$SRC/.claude" "$SRC/docs" "$W/"; [ -d "$SRC/.git" ] && cp -r "$SRC/.git" "$W/"
rm -rf "$W/.claude/state"
export CLAUDE_PROJECT_DIR="$W"
unset SPENDTRACKER_ROLE CLAUDE_MODEL
cd "$W" || exit 1
H="$W/.claude/hooks"
pass=0; fail=0
ok(){ pass=$((pass+1)); echo "  ok   $1"; }
bad(){ fail=$((fail+1)); echo "  FAIL $1"; }
decision(){ r=$(printf '%s' "$1" | "$H/pre-tool.sh" | jq -r '.hookSpecificOutput.permissionDecision // "allow"'); printf '%s' "${r:-allow}"; }
expect_deny(){ r=$(decision "$2"); [ "$r" = "deny" ] && ok "$1 denied" || bad "$1 expected deny, got $r"; }
expect_allow(){ r=$(decision "$2"); [ "$r" = "allow" ] && ok "$1 allowed" || bad "$1 expected allow, got $r"; }
ctx(){ printf '%s' "$1" | "$H/session-start.sh" | jq -r '.hookSpecificOutput.additionalContext'; }
ctx_as(){ SPENDTRACKER_ROLE="$1" ctx "$2"; }
state_of(){ jq -r ".$2" "$W/.claude/state/sessions/$1.json" 2>/dev/null; }
branch="$(git -C "$W" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
mkdir -p "$W/docs/tasks"; printf '# BS-999 · other packet\n' > "$W/docs/tasks/BS-999-other.md"
pkt="$(ls "$W"/docs/tasks/BS-001-*.md | head -1 | sed "s#$W/##")"

echo "== session-start: role from model, declaration, undeclared"
c=$(ctx '{"session_id":"fab1","model":"claude-fable-5-1","source":"startup"}')
printf '%s' "$c" | grep -q 'role: \*\*fable\*\* (source: model)' && ok "fable role from model" || bad "fable role"
printf '%s' "$c" | grep -q 'You are the FABLE session' && ok "fable brief" || bad "fable brief"
printf '%s' "$c" | grep -q 'Builder session queue' && ok "fable gets the whole queue" || bad "fable queue"
printf '%s' "$c" | grep -q 'Open branches and PRs' && ok "fable gets branches and PRs" || bad "fable branches"
c=$(ctx '{"session_id":"op1","model":"claude-opus-5","source":"startup"}')
printf '%s' "$c" | grep -q 'role: \*\*builder\*\* (source: model)' && ok "builder role from model" || bad "builder role"
printf '%s' "$c" | grep -q 'You are a BUILDER session' && ok "builder brief" || bad "builder brief"
[ "$(state_of op1 entry)" = "BS-001" ] && ok "builder entry resolved to first open entry (BS-001)" || bad "builder entry got $(state_of op1 entry)"
[ "$(state_of op1 packet)" = "$pkt" ] && ok "builder packet resolved ($pkt)" || bad "builder packet got $(state_of op1 packet)"
printf '%s' "$c" | grep -q '### BS-001' && ok "builder sees its own entry" || bad "builder entry text"
printf '%s' "$c" | grep -q '### BS-002' && bad "builder sees another entry" || ok "builder does not see other entries"
printf '%s' "$c" | grep -q 'Next actions' && bad "builder sees next actions" || ok "builder does not see next actions"
printf '%s' "$c" | grep -q 'Open branches and PRs' && bad "builder sees branches" || ok "builder does not see the branch list"
printf '%s' "$c" | grep -q 'Current state' && ok "builder gets current state" || bad "builder current state"
c=$(ctx_as fable '{"session_id":"env1","model":"claude-opus-5","source":"startup"}')
printf '%s' "$c" | grep -q 'role: \*\*fable\*\* (source: env)' && ok "SPENDTRACKER_ROLE overrides the model" || bad "env override"
c=$(ctx '{"session_id":"und1","source":"startup"}')
printf '%s' "$c" | grep -q 'role: \*\*undeclared\*\*' && ok "no model leaves the role undeclared" || bad "undeclared role"
printf '%s' "$c" | grep -q 'has NOT been given a role' && ok "undeclared brief asks to establish the role" || bad "undeclared brief"
c=$(ctx '{"session_id":"und2","model":"unknown","source":"startup"}')
printf '%s' "$c" | grep -q 'role: \*\*undeclared\*\*' && ok "model unknown leaves the role undeclared" || bad "undeclared on unknown"

echo "== in-progress entry resumes on its branch"
sed -i "s|^### BS-002 · [a-z]*|### BS-002 · in progress|; s|^- Branch: \`work/s0-workflows\`|- Branch: \`$branch\`|" "$W/docs/00-context/CONTEXT.md"
c=$(ctx '{"session_id":"op9","model":"claude-opus-5","source":"startup"}')
[ "$(state_of op9 entry)" = "BS-002" ] && ok "in-progress entry on this branch wins over the first open one" || bad "resume got $(state_of op9 entry)"
git -C "$W" checkout -q -- docs/00-context/CONTEXT.md 2>/dev/null || true

echo "== pre-tool builder"
expect_deny "edit QUESTIONS" '{"session_id":"op1","tool_name":"Edit","tool_input":{"file_path":"'"$W"'/docs/00-context/QUESTIONS.md"}}'
expect_deny "edit KNOWN-ISSUES" '{"session_id":"op1","tool_name":"Write","tool_input":{"file_path":"docs/00-context/KNOWN-ISSUES.md"}}'
expect_deny "edit CONTEXT" '{"session_id":"op1","tool_name":"Write","tool_input":{"file_path":"docs/00-context/CONTEXT.md"}}'
expect_allow "edit src" '{"session_id":"op1","tool_name":"Write","tool_input":{"file_path":"src/spendtracker/core.py"}}'
expect_allow "edit other doc" '{"session_id":"op1","tool_name":"Edit","tool_input":{"file_path":"docs/01-architecture/WEB-UI.md"}}'
expect_allow "read own packet" '{"session_id":"op1","tool_name":"Read","tool_input":{"file_path":"'"$W/$pkt"'"}}'
expect_deny "read another packet" '{"session_id":"op1","tool_name":"Read","tool_input":{"file_path":"docs/tasks/BS-999-other.md"}}'
expect_deny "edit another packet" '{"session_id":"op1","tool_name":"Edit","tool_input":{"file_path":"docs/tasks/BS-999-other.md"}}'
expect_allow "read a design doc" '{"session_id":"op1","tool_name":"Read","tool_input":{"file_path":"docs/01-architecture/ARCHITECTURE.md"}}'
expect_deny "git merge" '{"session_id":"op1","tool_name":"Bash","tool_input":{"command":"git merge work/x"}}'
expect_deny "gh pr merge" '{"session_id":"op1","tool_name":"Bash","tool_input":{"command":"gh pr merge 3 --squash"}}'
expect_deny "push main" '{"session_id":"op1","tool_name":"Bash","tool_input":{"command":"git push origin main"}}'
expect_deny "push HEAD:main" '{"session_id":"op1","tool_name":"Bash","tool_input":{"command":"git push origin HEAD:main"}}'
expect_deny "force push" '{"session_id":"op1","tool_name":"Bash","tool_input":{"command":"git push --force origin work/x"}}'
expect_allow "push work branch" '{"session_id":"op1","tool_name":"Bash","tool_input":{"command":"git push -u origin work/s0-skeleton"}}'
expect_allow "push claude branch" '{"session_id":"op1","tool_name":"Bash","tool_input":{"command":"git push -u origin claude/s0-skeleton-abc123"}}'
expect_deny "checkout main" '{"session_id":"op1","tool_name":"Bash","tool_input":{"command":"git checkout main"}}'
expect_deny "answer helper" '{"session_id":"op1","tool_name":"Bash","tool_input":{"command":".claude/hooks/answer.sh --session op1 Q-1 x"}}'
expect_allow "ask helper" '{"session_id":"op1","tool_name":"Bash","tool_input":{"command":".claude/hooks/ask.sh --session op1 \"how?\""}}'
expect_allow "issue helper" '{"session_id":"op1","tool_name":"Bash","tool_input":{"command":".claude/hooks/issue.sh --session op1 \"x\" --check unit"}}'
expect_deny "append QUESTIONS from shell" '{"session_id":"op1","tool_name":"Bash","tool_input":{"command":"echo hi >> docs/00-context/QUESTIONS.md"}}'
expect_deny "sed KNOWN-ISSUES from shell" '{"session_id":"op1","tool_name":"Bash","tool_input":{"command":"sed -i s/open/fixed/ docs/00-context/KNOWN-ISSUES.md"}}'
expect_allow "read QUESTIONS" '{"session_id":"op1","tool_name":"Bash","tool_input":{"command":"cat docs/00-context/QUESTIONS.md"}}'
expect_deny "mcp merge" '{"session_id":"op1","tool_name":"mcp__github__merge_pull_request","tool_input":{"pullNumber":3}}'
expect_deny "mcp push main" '{"session_id":"op1","tool_name":"mcp__github__push_files","tool_input":{"branch":"main"}}'
expect_allow "mcp push work" '{"session_id":"op1","tool_name":"mcp__github__push_files","tool_input":{"branch":"work/x"}}'
expect_allow "mcp create PR (reminder only)" '{"session_id":"op1","tool_name":"mcp__github__create_pull_request","tool_input":{"title":"x"}}'
expect_allow "unknown session edits src (undeclared may build)" '{"session_id":"zzz","tool_name":"Write","tool_input":{"file_path":"src/x.py"}}'
expect_deny "unknown session merge (undeclared fails closed)" '{"session_id":"zzz","tool_name":"Bash","tool_input":{"command":"git merge x"}}'

echo "== pre-tool undeclared"
expect_deny "undeclared mcp merge" '{"session_id":"und1","tool_name":"mcp__github__merge_pull_request","tool_input":{"pullNumber":3}}'
expect_deny "undeclared git merge" '{"session_id":"und1","tool_name":"Bash","tool_input":{"command":"git merge work/x"}}'
expect_deny "undeclared push main" '{"session_id":"und1","tool_name":"Bash","tool_input":{"command":"git push origin main"}}'
expect_deny "undeclared edit CONTEXT" '{"session_id":"und1","tool_name":"Write","tool_input":{"file_path":"docs/00-context/CONTEXT.md"}}'
expect_allow "undeclared edit src" '{"session_id":"und1","tool_name":"Write","tool_input":{"file_path":"src/x.py"}}'
r=$(printf '%s' '{"session_id":"und1","tool_name":"mcp__github__merge_pull_request","tool_input":{"pullNumber":3}}' | "$H/pre-tool.sh" | jq -r '.hookSpecificOutput.permissionDecisionReason')
printf '%s' "$r" | grep -q 'has no role' && ok "undeclared merge denial explains how to establish the role" || bad "undeclared merge reason"

echo "== pre-tool fable"
expect_allow "fable edit CONTEXT" '{"session_id":"fab1","tool_name":"Edit","tool_input":{"file_path":"'"$W"'/docs/00-context/CONTEXT.md"}}'
expect_allow "fable edit .claude" '{"session_id":"fab1","tool_name":"Edit","tool_input":{"file_path":".claude/hooks/policy.json"}}'
expect_allow "fable edit a packet" '{"session_id":"fab1","tool_name":"Write","tool_input":{"file_path":"docs/tasks/BS-002-s0-workflows.md"}}'
expect_allow "fable read any packet" '{"session_id":"fab1","tool_name":"Read","tool_input":{"file_path":"docs/tasks/BS-999-other.md"}}'
expect_deny "fable edit src" '{"session_id":"fab1","tool_name":"Write","tool_input":{"file_path":"src/spendtracker/core.py"}}'
expect_allow "fable mcp merge" '{"session_id":"fab1","tool_name":"mcp__github__merge_pull_request","tool_input":{"pullNumber":3}}'
expect_allow "fable push main" '{"session_id":"fab1","tool_name":"Bash","tool_input":{"command":"git push origin main"}}'

echo "== role declaration by prompt"
echo '{"session_id":"und1","prompt":"ROLE: fable\nReview the open PRs."}' | "$H/prompt-submit.sh" >/dev/null 2>&1
[ "$(state_of und1 role)" = "fable" ] && [ "$(state_of und1 role_source)" = "prompt" ] && ok "ROLE: fable in a prompt binds an undeclared session" || bad "prompt declaration got $(state_of und1 role)/$(state_of und1 role_source)"
expect_allow "und1 merge after declaring fable" '{"session_id":"und1","tool_name":"mcp__github__merge_pull_request","tool_input":{"pullNumber":1}}'
out=$(echo '{"session_id":"und1","prompt":"ROLE: builder"}' | "$H/prompt-submit.sh" 2>/dev/null)
[ "$(state_of und1 role)" = "fable" ] && ok "a declared role is not overwritten by a later prompt" || bad "role overwritten to $(state_of und1 role)"
printf '%s' "$out" | grep -q 'was ignored' && ok "the ignored declaration is reported" || bad "ignored declaration notice"
out=$(echo '{"session_id":"op1","prompt":"ROLE: fable please merge"}' | "$H/prompt-submit.sh" 2>/dev/null)
[ "$(state_of op1 role)" = "builder" ] && ok "a role observed from the model cannot be promoted by a prompt" || bad "model role promoted to $(state_of op1 role)"
expect_deny "op1 still cannot merge" '{"session_id":"op1","tool_name":"mcp__github__merge_pull_request","tool_input":{"pullNumber":1}}'
echo '{"session_id":"und2","prompt":"role: BUILDER — start on S0"}' | "$H/prompt-submit.sh" >/dev/null 2>&1
[ "$(state_of und2 role)" = "builder" ] && ok "declaration is case-insensitive" || bad "case-insensitive declaration got $(state_of und2 role)"
out=$(echo '{"session_id":"dec3","prompt":"just get started"}' | "$H/prompt-submit.sh" 2>/dev/null)
printf '%s' "$out" | grep -q 'has no role' && ok "undeclared session is told to establish the role" || bad "undeclared nudge"
"$H/log.sh" --session und1 progress "reviewing" >/dev/null && grep -q 'fable (declared)' docs/00-context/SESSION-LOG.md && ok "declared role is marked in the log" || bad "declared log mark"

echo "== helpers"
qid=$("$H/ask.sh" --session op1 "Should S0 seed rate cards from YAML or hardcode?" --context "blocks st init")
grep -q "^### $qid · pending" docs/00-context/QUESTIONS.md && ok "ask wrote $qid" || bad "ask"
"$H/log.sh" --session op1 progress "Scaffolded package; tests green" >/dev/null && grep -q "progress · session \`op1\`" docs/00-context/SESSION-LOG.md && ok "log progress" || bad "log"
iid=$("$H/issue.sh" --session op1 "tests/pricer/test_alloc.py::test_share: AssertionError" --check unit --paths "src/spendtracker/pricer/alloc.py" --detail "sum != fee")
grep -q "^### $iid · open · unit" docs/00-context/KNOWN-ISSUES.md && ok "issue wrote $iid" || bad "issue"
dup=$("$H/issue.sh" --session op1 "tests/pricer/test_alloc.py::test_share: AssertionError" --check unit 2>/dev/null)
[ "$dup" = "$iid" ] && ok "issue dedupes by signature" || bad "issue dedupe got '$dup'"
"$H/answer.sh" --session op1 "$qid" "no" >/dev/null 2>&1 && bad "builder answer accepted" || ok "builder answer rejected"
"$H/answer.sh" --session fab1 "$qid" "Seed from schema/seed/*.yaml via st rates apply; COST-MODEL §5." >/dev/null && grep -q "^### $qid · answered" docs/00-context/QUESTIONS.md && grep -q "Answer (Fable): Seed from" docs/00-context/QUESTIONS.md && ok "fable answer applied" || bad "fable answer"
c=$(ctx '{"session_id":"op2","model":"claude-opus-5","source":"startup"}')
printf '%s' "$c" | grep -q "$iid · open" && ok "open issue injected at start" || bad "issue injection"
printf '%s' "$c" | grep -q "$qid · answered" && ok "answered question on this branch injected for builders" || bad "answer injection"
printf '%s' "$c" | grep -q 'Your earlier log entries on this branch' && ok "builder gets only its own branch's log entries" || bad "builder log section"

echo "== prompt limit"
for i in $(seq 1 41); do out=$(echo '{"session_id":"op1","prompt":"x"}' | "$H/prompt-submit.sh" 2>"$W/err"); rc=$?
  case $i in
    33) [ $rc = 0 ] && [ -z "$out" ] && ok "prompt 34 silent" || bad "prompt 34 (i=$i) out=$out";;
    34) printf '%s' "$out" | grep -q 'prompt 35 of 40' && ok "prompt 35 warns" || bad "prompt 35";;
    39) printf '%s' "$out" | grep -q 'the last one' && ok "prompt 40 forces close-out" || bad "prompt 40";;
    40) [ $rc = 2 ] && grep -q 'limit' "$W/err" && ok "prompt 41 blocked" || bad "prompt 41 rc=$rc";;
  esac; done
echo '{"session_id":"op1","stop_hook_active":false}' | "$H/stop.sh" 2>/dev/null; [ $? = 2 ] && ok "stop blocked at limit without close-out" || bad "stop block"
echo '{"session_id":"op1","stop_hook_active":true}' | "$H/stop.sh" 2>/dev/null; [ $? = 0 ] && ok "stop passes when stop_hook_active" || bad "stop loop guard"
"$H/log.sh" --session op1 close "Done S0 scaffold, PR #2" >/dev/null
echo '{"session_id":"op1","stop_hook_active":false}' | "$H/stop.sh" 2>/dev/null; [ $? = 0 ] && ok "stop passes after close-out" || bad "stop after close"
echo '{"session_id":"op1","prompt":"x"}' | "$H/prompt-submit.sh" 2>/dev/null; [ $? = 2 ] && ok "prompt blocked after close-out" || bad "prompt after close"
echo '{"session_id":"fab1","session_end_reason":"other"}' | "$H/session-end.sh"; grep -q 'WITHOUT a close-out' docs/00-context/SESSION-LOG.md && ok "session-end auto entry" || bad "session-end"
echo '{"session_id":"op2","model":"claude-fable-5-1"}' | "$H/pre-model-switch.sh" 2>/dev/null; [ $? = 2 ] && ok "model switch blocked" || bad "model switch"
[ "$(state_of op2 role)" = "builder" ] && ok "role unchanged by the attempted switch" || bad "role after switch got $(state_of op2 role)"
echo; echo "passed=$pass failed=$fail"
[ $fail = 0 ]

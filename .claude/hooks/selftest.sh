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
unset SPENDTRACKER_ROLE
cd "$W" || exit 1
H="$W/.claude/hooks"
pass=0; fail=0
ok(){ pass=$((pass+1)); echo "  ok   $1"; }
bad(){ fail=$((fail+1)); echo "  FAIL $1"; }
decision(){ r=$(printf '%s' "$1" | "$H/pre-tool.sh" | jq -r '.hookSpecificOutput.permissionDecision // "allow"'); printf '%s' "${r:-allow}"; }
expect_deny(){ r=$(decision "$2"); [ "$r" = "deny" ] && ok "$1 denied" || bad "$1 expected deny, got $r"; }
expect_allow(){ r=$(decision "$2"); [ "$r" = "allow" ] && ok "$1 allowed" || bad "$1 expected allow, got $r"; }
ctx(){ printf '%s' "$1" | "$H/session-start.sh" | jq -r '.hookSpecificOutput.additionalContext'; }

echo "== session-start"
c=$(ctx '{"session_id":"fab1","model":"claude-fable-5-1","source":"startup"}')
printf '%s' "$c" | grep -q 'role: \*\*fable\*\*' && ok "fable role detected" || bad "fable role"
printf '%s' "$c" | grep -q 'You are the FABLE session' && ok "fable brief" || bad "fable brief"
printf '%s' "$c" | grep -q 'Current state' && ok "CONTEXT.md injected" || bad "CONTEXT.md injected"
c=$(ctx '{"session_id":"op1","model":"claude-opus-5","source":"startup"}')
printf '%s' "$c" | grep -q 'role: \*\*builder\*\*' && ok "builder role detected" || bad "builder role"
printf '%s' "$c" | grep -q 'You are a BUILDER session' && ok "builder brief" || bad "builder brief"

echo "== pre-tool builder"
expect_deny "edit QUESTIONS" '{"session_id":"op1","tool_name":"Edit","tool_input":{"file_path":"'"$W"'/docs/00-context/QUESTIONS.md"}}'
expect_deny "edit KNOWN-ISSUES" '{"session_id":"op1","tool_name":"Write","tool_input":{"file_path":"docs/00-context/KNOWN-ISSUES.md"}}'
expect_deny "edit CONTEXT" '{"session_id":"op1","tool_name":"Write","tool_input":{"file_path":"docs/00-context/CONTEXT.md"}}'
expect_allow "edit src" '{"session_id":"op1","tool_name":"Write","tool_input":{"file_path":"src/spendtracker/core.py"}}'
expect_allow "edit other doc" '{"session_id":"op1","tool_name":"Edit","tool_input":{"file_path":"docs/01-architecture/WEB-UI.md"}}'
expect_deny "git merge" '{"session_id":"op1","tool_name":"Bash","tool_input":{"command":"git merge work/x"}}'
expect_deny "gh pr merge" '{"session_id":"op1","tool_name":"Bash","tool_input":{"command":"gh pr merge 3 --squash"}}'
expect_deny "push main" '{"session_id":"op1","tool_name":"Bash","tool_input":{"command":"git push origin main"}}'
expect_deny "push HEAD:main" '{"session_id":"op1","tool_name":"Bash","tool_input":{"command":"git push origin HEAD:main"}}'
expect_deny "force push" '{"session_id":"op1","tool_name":"Bash","tool_input":{"command":"git push --force origin work/x"}}'
expect_allow "push work branch" '{"session_id":"op1","tool_name":"Bash","tool_input":{"command":"git push -u origin work/s0-skeleton"}}'
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
expect_allow "unknown session edits src (builder default)" '{"session_id":"zzz","tool_name":"Write","tool_input":{"file_path":"src/x.py"}}'
expect_deny "unknown session merge (builder default)" '{"session_id":"zzz","tool_name":"Bash","tool_input":{"command":"git merge x"}}'

echo "== pre-tool fable"
expect_allow "fable edit CONTEXT" '{"session_id":"fab1","tool_name":"Edit","tool_input":{"file_path":"'"$W"'/docs/00-context/CONTEXT.md"}}'
expect_allow "fable edit .claude" '{"session_id":"fab1","tool_name":"Edit","tool_input":{"file_path":".claude/hooks/policy.json"}}'
expect_deny "fable edit src" '{"session_id":"fab1","tool_name":"Write","tool_input":{"file_path":"src/spendtracker/core.py"}}'
expect_allow "fable mcp merge" '{"session_id":"fab1","tool_name":"mcp__github__merge_pull_request","tool_input":{"pullNumber":3}}'
expect_allow "fable push main" '{"session_id":"fab1","tool_name":"Bash","tool_input":{"command":"git push origin main"}}'

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

echo "== prompt limit"
for i in $(seq 1 41); do out=$(echo '{"session_id":"op1","prompt":"x"}' | "$H/prompt-submit.sh" 2>"$W/err"); rc=$?
  case $i in
    34) [ $rc = 0 ] && [ -z "$out" ] && ok "prompt 34 silent" || bad "prompt 34";;
    35) printf '%s' "$out" | grep -q 'prompt 35 of 40' && ok "prompt 35 warns" || bad "prompt 35";;
    40) printf '%s' "$out" | grep -q 'the last one' && ok "prompt 40 forces close-out" || bad "prompt 40";;
    41) [ $rc = 2 ] && grep -q 'limit' "$W/err" && ok "prompt 41 blocked" || bad "prompt 41 rc=$rc";;
  esac; done
echo '{"session_id":"op1","stop_hook_active":false}' | "$H/stop.sh" 2>/dev/null; [ $? = 2 ] && ok "stop blocked at limit without close-out" || bad "stop block"
echo '{"session_id":"op1","stop_hook_active":true}' | "$H/stop.sh" 2>/dev/null; [ $? = 0 ] && ok "stop passes when stop_hook_active" || bad "stop loop guard"
"$H/log.sh" --session op1 close "Done S0 scaffold, PR #2" >/dev/null
echo '{"session_id":"op1","stop_hook_active":false}' | "$H/stop.sh" 2>/dev/null; [ $? = 0 ] && ok "stop passes after close-out" || bad "stop after close"
echo '{"session_id":"op1","prompt":"x"}' | "$H/prompt-submit.sh" 2>/dev/null; [ $? = 2 ] && ok "prompt blocked after close-out" || bad "prompt after close"
echo '{"session_id":"fab1","session_end_reason":"other"}' | "$H/session-end.sh"; grep -q 'WITHOUT a close-out' docs/00-context/SESSION-LOG.md && ok "session-end auto entry" || bad "session-end"
echo '{"session_id":"op1"}' | "$H/pre-model-switch.sh" 2>/dev/null; [ $? = 2 ] && ok "model switch blocked" || bad "model switch"
echo; echo "passed=$pass failed=$fail"
[ $fail = 0 ]

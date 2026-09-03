#!/usr/bin/env bash
# PreToolUse: enforce role policy.
#   builder: no merges, no pushes to protected branches, no direct edits to the ledger files
#            (QUESTIONS.md, SESSION-LOG.md, KNOWN-ISSUES.md, CONTEXT.md), no answer.sh.
#   fable:   edits only under fable_editable_paths (review, answer, merge, check in; no building).
#   all:     PRs are opened under the owner's GitHub username (pr_author_login).
set -u
. "$(dirname "$0")/lib.sh"
input="$(cat)"
sid="$(printf '%s' "$input" | jq -r '.session_id // "unknown"')"
tool="$(printf '%s' "$input" | jq -r '.tool_name // empty')"
st_state_ensure "$sid" >/dev/null
printf '%s' "$sid" > "$ST_STATE_DIR/last-tool-session" 2>/dev/null || true
role="$(st_role "$sid")"
prot="$(st_policy '.protected_branches | join("|")')"

rel() { # absolute or relative path -> path relative to repo root
  local p="$1"; case "$p" in "$ST_ROOT"/*) p="${p#"$ST_ROOT"/}";; esac; printf '%s' "$p"
}

case "$tool" in
  Edit|Write|MultiEdit|NotebookEdit)
    path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')"
    [ -z "$path" ] && exit 0
    rp="$(rel "$path")"
    if [ "$role" = "builder" ]; then
      while IFS= read -r ro; do
        [ -n "$ro" ] && [ "$rp" = "$ro" ] && st_deny "Builder sessions may not edit $ro directly. Use .claude/hooks/ask.sh to ask a question or .claude/hooks/log.sh to record progress; only the Fable session answers questions and updates CONTEXT.md."
      done < <(st_policy '.builder_readonly_paths[]')
    else
      ok=0
      while IFS= read -r allow; do
        [ -n "$allow" ] && case "$rp" in "$allow"*) ok=1;; esac
      done < <(st_policy '.fable_editable_paths[]')
      [ "$ok" = 1 ] || st_deny "Fable sessions review, answer, evaluate CI and merge; they do not build. $rp is outside the Fable-editable paths (see .claude/hooks/policy.json). Record the needed change as a next action in CONTEXT.md for a builder session."
    fi
    ;;
  Bash)
    cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
    if [ "$role" = "builder" ]; then
      printf '%s' "$cmd" | grep -Eq '(^|[;&|[:space:]])git[[:space:]]+merge\b' && st_deny "Builder sessions may not merge. Open or update your PR; the Fable session merges after CI and answers."
      printf '%s' "$cmd" | grep -Eq 'gh[[:space:]]+pr[[:space:]]+merge' && st_deny "Builder sessions may not merge PRs."
      printf '%s' "$cmd" | grep -Eq "git[[:space:]]+push\b.*(\b($prot)\b|--force|-f\b|\+[[:alnum:]/_-]*:)" && st_deny "Builder sessions may not push to protected branches ($prot) or force-push. Push your work/* branch and open a PR."
      printf '%s' "$cmd" | grep -Eq "git[[:space:]]+(checkout|switch)[[:space:]]+($prot)\b" && st_deny "Builder sessions work on their own branch, not $prot."
      printf '%s' "$cmd" | grep -Eq 'answer\.sh' && st_deny "Only the Fable session answers questions."
      for ro in $(st_policy '.builder_readonly_paths[]'); do
        b="$(basename "$ro")"
        if printf '%s' "$cmd" | grep -q "$b" && ! printf '%s' "$cmd" | grep -Eq '\.claude/hooks/(ask|log|issue)\.sh'; then
          printf '%s' "$cmd" | grep -Eq "(>|>>|sed[[:space:]]+-i|tee|mv|cp|rm)[^|]*$b" && st_deny "Builder sessions may not write $ro from the shell. Use .claude/hooks/ask.sh, log.sh or issue.sh."
        fi
      done
    fi
    # Hard rule (all roles): PRs are opened under the owner's GitHub username. Best-effort check when gh is present.
    if printf '%s' "$cmd" | grep -Eq 'gh[[:space:]]+pr[[:space:]]+create'; then
      want="$(st_policy '.pr_author_login')"
      if command -v gh >/dev/null 2>&1; then
        have="$(timeout 10 gh api user -q .login 2>/dev/null || true)"
        [ -n "$have" ] && [ "$have" != "$want" ] && st_deny "PRs must be opened by the GitHub user '$want' (policy pr_author_login); gh is authenticated as '$have'."
      fi
    fi
    ;;
  mcp__github__create_pull_request)
    # Identity cannot be checked here; CI's pr-author job enforces it. Remind the session of the rule.
    jq -n --arg w "$(st_policy '.pr_author_login')" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",additionalContext:("Protocol: this PR must be authored by GitHub user " + $w + "; CI rejects PRs from any other identity. Create it as a draft.")}}'
    exit 0
    ;;
  mcp__github__merge_pull_request|mcp__github__enable_pr_auto_merge)
    [ "$role" = "builder" ] && st_deny "Builder sessions may not merge PRs; the Fable session merges after CI passes and questions are answered."
    ;;
  mcp__github__push_files|mcp__github__create_or_update_file|mcp__github__delete_file)
    br="$(printf '%s' "$input" | jq -r '.tool_input.branch // empty')"
    if [ "$role" = "builder" ] && printf '%s' "$br" | grep -Eq "^($prot)$"; then st_deny "Builder sessions may not write to $br."; fi
    ;;
esac
exit 0

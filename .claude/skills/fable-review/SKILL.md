---
name: fable-review
description: The Fable session's checklist. Read the context ledger, answer pending questions, curate the known-issues ledger from CI output, review builder PRs and their CI tiers (unit, integration, system, blast radius), merge what is green and answered, update CONTEXT.md, check in, close out.
---

# Fable review

Your session id is in the SessionStart context. Use it as `<sid>`.

1. **Read** `docs/00-context/CONTEXT.md` fully, then the pending questions, open known issues and last session-log entries shown at session start. Read open `ct` issues on GitHub if any.
2. **Answer every pending question** on this branch and on other branches (the start context lists them with their branch). Check the branch out when the question lives there:
   `.claude/hooks/answer.sh --session <sid> Q-id "answer"` or `--needs-human` when only the owner can decide. Give reasons and point to the doc or ADR that settles it; add an ADR if the answer is a new decision.
3. **Bring the known-issues ledger up to date.** For each open builder PR, read the CI issue output (the `ci-issues` artifact and the CI comment on the PR). Every distinct failure gets an entry in `docs/00-context/KNOWN-ISSUES.md` via `.claude/hooks/issue.sh` if missing; mark fixed ones `fixed` with the commit; assign open ones to a next action for a builder with the exact check name, error signature and the paths in its blast radius.
4. **Review each open builder PR**: read its diff and the builder's session-log entries; check the head commit's check runs (`pull_request_read` with `get_check_runs`). Required check names contain `unit`, `integration` and `system` (`.claude/hooks/policy.json`). Confirm the CI run covered the change's blast radius (the `blast-radius` job summary lists selected tiers and paths); if the change touched core or schema paths, a full run is required. While the repo has no CI yet, say so in the log and treat the PR as not mergeable unless the user overrides.
5. **Verify the PR author** is the owner's GitHub username (`pr_author_login` in policy.json). A PR opened by any other identity is not merged; log it as a protocol violation.
6. **Merge** PRs that are green, mergeable, author-compliant and whose questions are answered and whose issues are recorded (squash unless the repo says otherwise). Leave a one-line PR comment naming what was verified. Do not merge red, conflicted or unanswered PRs; log why and what the builder must do next.
7. **Update `CONTEXT.md`**: current state, next actions (one per future builder session, sized for 40 prompts, referencing issue ids to fix), decisions log, open questions, phase history. Commit to main and push.
8. **Close**: `.claude/hooks/log.sh --session <sid> close "<what was answered, curated, merged, deferred>"`, then stop.

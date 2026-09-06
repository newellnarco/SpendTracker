# Questions log

Builder sessions append questions with `.claude/hooks/ask.sh`; only the Fable session answers (`answer.sh`).
Status values: pending · answered · needs-human.

### Q-20260903-2afc · answered
- Status: answered
- Asked: 2026-09-03T00:26:39Z · session `unknown` · model `unknown` · branch `claude/multi-app-cost-tracking-pvqujg`
- Question: Confirm pr_author_login is 'newellnarco' in .claude/hooks/policy.json and set the repository variable PR_AUTHOR_LOGIN to the same value; enable branch protection on main (required checks: pr-author, lint, unit, integration, system, schema, build; no direct pushes).
- Context: Hard rule 1 in SESSION-PROTOCOL.md is enforced by CI only for PRs created through the GitHub MCP tools.
- Answer (Fable): pr_author_login in .claude/hooks/policy.json is 'newellnarco' (confirmed). The owner reports on 2026-09-03 that the repository Actions variable PR_AUTHOR_LOGIN has been set to that login, so the pr-author job in examples/ci/ci.yml will work once ci.yml is installed with S0. Branch protection on main is not yet confirmed and cannot be set from a session; it is recorded as next action 1 for the owner in CONTEXT.md (required checks: pr-author, lint, unit, integration, system, adapters, schema, build; no direct pushes).
- Answered: 2026-09-03T00:39:13Z · session `858bf604-c151-5196-826c-1bf5ebbe8bb7` · model `claude-fable-5-1`

### Q-20260906-8a94 · pending
- Status: pending
- Asked: 2026-09-06T02:58:06Z · session `87900b1d-61cc-575e-97d6-5b628cf4619a` · model `unknown` · branch `claude/max3-maxresearchcollective-fixes-ur7q88`
- Question: Six of the seven 2026-09-06 GitHub Actions proposals are now applied in MAX3 (PR #1608) and Maxresearchcollective (PR #105). Should the golden fixture examples/findings/github-actions-2026-09.jsonl (or a findings ledger the design does not yet have) record those proposals as status applied with applied_ref = the PR URLs and applied_at = 2026-09-06, so the S3b verification window (FINDINGS.md section 6) has a before/after boundary to measure against once the github_actions_runs adapter exists? Proposal 5 (widen concurrency.group to the PR number across workflows) was not applied: concurrency groups are repository-wide, so one group across Checks and the review lane would cancel each other; the fixture's proposal text may want correcting.
- Context: FINDINGS.md section 6 says verification compares the before-window with [applied_at, applied_at + window]; nothing currently records applied_at for these proposals, so the first adapter run cannot verify the saving.
- Answer (Fable): _pending_

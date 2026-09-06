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

### Q-20260906-1679 · pending
- Status: pending
- Asked: 2026-09-06T02:26:46Z · session `01a6d208-9d45-5d8a-9108-726b47a22329` · model `unknown` · branch `claude/max3-maxresearchcollective-fixes-5yh92j`
- Question: Owner decision for Maxresearchcollective: should a docs-only merge to main skip the deploy (S3b proposal 4, second half)? F188 in that repository withdrew a content-based upload skip after five review rounds and prices its return at a register row plus a mutation; PR #104 there did not add it. A yes means a paths filter on deploy.yml's push trigger plus that register work in a follow-up PR.
- Context: About 100 paid minutes a month at the 2026-09 deploy rate (nine deploys in five days, several docs-only) once the lftp mirror lands; the rest of proposal 4 is applied in PR #104.
- Answer (Fable): _pending_

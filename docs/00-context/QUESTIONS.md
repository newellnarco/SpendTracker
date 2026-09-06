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

### Q-20260906-c901 · pending
- Status: pending
- Asked: 2026-09-06T01:53:58Z · session `8a142028-580c-5980-8a46-d4480bbcb9cc` · model `unknown` · branch `claude/github-action-minutes-usage-oz4jr0`
- Question: Which repositories should the github_actions_runs adapter (COLLECTORS.md §4b, slice S3b) be configured for, and does the billing page's 'All other repositories' line ($12.07 on 2026-09-06, larger than any single repository) resolve to a repository once the Usage page is filtered to product = Actions and the usage report CSV is downloaded? The three older private repositories have zero runs; the GitHub App cannot see repositories it is not installed on.
- Context: Extends Q-2. The S3b exit criteria and the golden fixture assume the four visible repositories; an unattributed repository would need the app installed and the adapter config extended before rule gha.unattributed_spend can close.
- Answer (Fable): _pending_

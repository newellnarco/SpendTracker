# Known issues ledger

Every CI failure and observed defect gets an entry via `.claude/hooks/issue.sh`. Sessions read open entries at start so they are not reproduced. The Fable session keeps this file current (status, assignment, fix reference).
Status values: open · fixed · wontfix.

### I-20260903-cbb7 · fixed · other
- Status: fixed
- Title: CONTEXT.md not updated for ADR-0007/ADR-0008: the design session was classed as builder by its own new hooks
- Signature: a1cf52d845
- Check: other
- Blast radius: docs/00-context/CONTEXT.md
- Detail: Next Fable session: add decision rows for ADR-0007 and ADR-0008, note that only Fable edits CONTEXT.md, add next actions: set PR_AUTHOR_LOGIN variable, enable branch protection, copy examples/ci/ci.yml when S0 lands; phase history row 0b.
- Ref: CONTEXT.md updated on branch `claude/context-md-fable-session-x3dgcu` (stacked on PR #1) by the Fable session on 2026-09-03
- Recorded: 2026-09-03T00:26:39Z · session `unknown` · model `unknown` · builder · branch `claude/multi-app-cost-tracking-pvqujg`
- Assigned: Fable session `858bf604-c151-5196-826c-1bf5ebbe8bb7` · fixed 2026-09-03

### I-20260906-e7c0 · open · other
- Status: open
- Title: S3b finding gha.duplicate_gate_on_deploy and proposal 3 assume a duplicate that does not exist
- Signature: a3e9a6ef52
- Check: other
- Blast radius: docs/00-context/research/S3-github-actions-run-usage.md,docs/01-architecture/FINDINGS.md,examples/findings/github-actions-2026-09.jsonl
- Detail: On branch claude/github-action-minutes-usage-oz4jr0 the finding says Maxresearchcollective's deploy gate-mutation-1..4 re-run a job set that already passed on the same tree in Checks. Checks on a PR runs guard_mutation_test --changed (the diff's blast radius), never the four full shards; deploy.yml is the only full mutation run before a deploy and site_health_test.mjs asserts it. The counterfactual (skip the gate on a tree-SHA match) removes coverage, not duplication, so the 300-minute waste_quantity and the 108000 est_saving in the golden fixture are wrong and the rule gha.duplicate_gate_on_deploy needs a job-set equality check that compares the commands run, not job names. Not applied in Maxresearchcollective PR #104.
- Recorded: 2026-09-06T02:26:46Z · session `01a6d208-9d45-5d8a-9108-726b47a22329` · model `unknown` · builder · branch `claude/max3-maxresearchcollective-fixes-5yh92j`
- Assigned: _unassigned_

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

### I-20260903-f7d2 · fixed · other
- Status: fixed
- Title: SessionStart hook receives no model in cloud sessions, so every session was classed as a builder
- Signature: fa508f5b47
- Check: other
- Blast radius: .claude/hooks/lib.sh,.claude/hooks/session-start.sh,.claude/hooks/prompt-submit.sh
- Detail: Sessions 858bf604, ac98103e and 475ebbee all recorded model unknown and role builder; Fable sessions corrected their own state by hand after get_session. Fixed by ADR-0009: role from the observed model when reported, else undeclared (fail closed) until a ROLE: declaration; role_source recorded; log marks declared roles.
- Ref: ADR-0009, branch claude/design-review-export-fsy8j1
- Recorded: 2026-09-03T04:56:37Z · session `475ebbee-ad73-515a-98ba-6f9a6b3582e7` · model `claude-fable-5-1` · fable · branch `claude/design-review-export-fsy8j1`
- Assigned: _unassigned_

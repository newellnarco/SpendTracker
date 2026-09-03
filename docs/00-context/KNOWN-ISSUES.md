# Known issues ledger

Every CI failure and observed defect gets an entry via `.claude/hooks/issue.sh`. Sessions read open entries at start so they are not reproduced. The Fable session keeps this file current (status, assignment, fix reference).
Status values: open · fixed · wontfix.

### I-20260903-cbb7 · open · other
- Status: open
- Title: CONTEXT.md not updated for ADR-0007/ADR-0008: the design session was classed as builder by its own new hooks
- Signature: a1cf52d845
- Check: other
- Blast radius: docs/00-context/CONTEXT.md
- Detail: Next Fable session: add decision rows for ADR-0007 and ADR-0008, note that only Fable edits CONTEXT.md, add next actions: set PR_AUTHOR_LOGIN variable, enable branch protection, copy examples/ci/ci.yml when S0 lands; phase history row 0b.
- Recorded: 2026-09-03T00:26:39Z · session `unknown` · model `unknown` · builder · branch `claude/multi-app-cost-tracking-pvqujg`
- Assigned: _unassigned_

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

### I-20260906-c1c9 · open · other
- Status: open
- Title: pre-tool hook denies read-only git commands whose text contains 'merge' (git merge-base, and any ask/issue text mentioning it)
- Signature: 01a80adfd2
- Check: other
- Blast radius: .claude/hooks/pre-tool.sh,.claude/hooks/policy.json
- Detail: Running 'git merge-base --is-ancestor origin/main HEAD' in a builder session was denied with the builder-may-not-merge message; so was an ask.sh/issue.sh call whose quoted text contained the word. The deny pattern matches the substring anywhere in the command rather than the git subcommand; 'git merge-base' and 'git merge-tree' are read-only. Repro: any Bash tool call containing that word.
- Recorded: 2026-09-06T01:53:58Z · session `8a142028-580c-5980-8a46-d4480bbcb9cc` · model `unknown` · builder · branch `claude/github-action-minutes-usage-oz4jr0`
- Assigned: _unassigned_

# ADR-0011: Findings and proposals are derived rows produced by rule packs

**Status:** Accepted — 2026-09-06 (numbered 0011 because ADR-0009 and ADR-0010 are taken on branch
`claude/design-review-export-fsy8j1`)

## Context

Recording usage and pricing it answers "what did it cost". The owner's question on 2026-09-06 was
"why did GitHub use all 3,000 Actions minutes in five days, and what do I change". Answering it took
a session several hours: pull every run and job for a month, price jobs by runner label, group by
workflow, job, trigger and branch, read the workflow files, and turn each cause into a change with an
estimated saving (research note `S3-github-actions-run-usage.md`). Nothing in the design captured
that work: the GitHub adapter (COLLECTORS.md §4) stops at billing lines per repository per day, and
the UI has no place for "this is waste and here is the fix".

The same shape recurs for every layer: a Claude Code session that re-reads a 400 KB file each turn,
a subscription with 3 % utilization (COST-MODEL.md §4 already calls that "the signal to downgrade"
without recording it anywhere), an MCP server called 1,000 times a day returning errors.

## Decision

1. **Findings and proposals are first-class, derived data.** A `finding` is one detected instance
   of a waste or risk pattern over a scope and period, with evidence and a quantified cost. A
   `proposal` is one concrete change attached to a finding with an estimated saving per period, an
   effort class, and a lifecycle (`open`, `accepted`, `applied`, `verified`, `dismissed`). Both are
   recomputable from `usage_event`, `cost_line` and adapter attributes, the way `cost_line` is
   recomputable from events. Human state (acceptance, dismissal, applied date, notes) is preserved
   across recomputation by a stable `signature`.
2. **Rules produce findings; rule packs ship with adapters.** A rule is a pure function over the
   store (`rule.evaluate(ctx, scope, period) -> Finding[]`) declared in a manifest with an id,
   the measures and attributes it reads, a severity function and a proposal template. Generic rules
   (subscription utilization, cancelled work, unpriced events) live in `core.findings`. Layer-specific
   rules live in the adapter directory (`adapters/github_actions_runs/rules/`) and are loaded with
   the adapter, so the core still never branches on an app id (ADR-0005).
3. **Evidence is stored, not re-derived at read time.** Each finding carries a JSON `evidence`
   block (the rows, ids and numbers that justify it: run ids, job names, branches, minutes) so the
   UI and the export can show why without re-querying, and so a finding survives compaction.
4. **Run-level collection is a separate adapter from billing.** `github_actions_runs` collects
   per-run and per-job facts (seconds by runner label, workflow, job, trigger, branch, conclusion) as
   usage events with `session = run id`. `github_billing` stays the source of reported cost. The
   pricer prices run seconds by a rate card per runner SKU; reconciliation compares the two.
5. **Savings are estimates with a stated basis.** A proposal records `basis` (`measured`,
   `extrapolated`, `assumed`) and the window it extrapolates from. The UI never shows a saving
   without its basis. A verified proposal replaces the estimate with the measured before/after
   difference.

## Alternatives considered

- **A report script per question** (what the session did by hand). Rejected: not repeatable, no
  lifecycle, nothing to compare next month against.
- **Findings as budget alerts.** Rejected: an alert says a number crossed a line; a finding says
  which mechanism is spending and what to change.
- **Rules in the core only.** Rejected: a GitHub Actions rule needs runner labels, workflow names
  and PR events that only the adapter understands; keeping rules beside the adapter keeps the core
  app-agnostic.
- **Modelling proposals as GitHub issues.** Deferred: `st findings export --github-issues` can
  create issues from accepted proposals later; the store stays the source of truth.

## Consequences

- Two tables (`finding`, `proposal`) and a rule manifest format (schema `002_findings.sql`,
  FINDINGS.md). `st findings run` is idempotent per (rule, scope, period).
- Adapters gain an optional `rules/` directory and a `rules:` list in `adapter.yaml`; the conformance
  suite replays each rule against its golden fixture (`examples/findings/*.jsonl`) and checks
  signatures are stable and evidence is complete.
- The GitHub Actions rule pack is the first pack and the 2026-09 analysis is its golden case. The
  seven proposals in the research note are the expected output for that fixture.
- Findings and proposals are included in the export (redaction applies to evidence) so the team
  rollup can rank waste across nodes.

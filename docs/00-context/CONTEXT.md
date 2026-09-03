# CONTEXT.md — the living ledger

This file is the handoff between phases, people and AI sessions. It is deliberately short.
Anything that needs more than a paragraph gets its own document and a link from here.

**Rules**
1. Read this file before doing anything in any phase (research, design, build, test, redesign).
2. Update it as the last step of every phase. A phase is not done until this file says so.
3. Never delete history here. Mark items superseded and link the replacement.
4. Keep the "Current state" block accurate enough that a fresh session can continue with no other input.

---

## Current state

| Field | Value |
| --- | --- |
| Active slice | S0 — Walking skeleton (not started) |
| Last completed slice | none |
| Schema version | 001 (designed, not applied) |
| Reference stack | Python 3.12, SQLite (WAL), FastAPI, htmx, Chart.js, Typer CLI (ADR-0006) |
| Local DB path | `~/.spendtracker/spend.db` |
| Rollup repo | to be created; layout in `01-architecture/AGGREGATION.md` |
| Reporting currency | USD (configurable, see COST-MODEL) |

## Next actions

1. Run the S0 phase per `02-delivery/PHASE-PLAYBOOK.md`: scaffold the package, apply `schema/001_core.sql`, implement `st ingest` from stdin, `st report`, `st serve` with a single total.
2. Create the CI workflow from `examples/ci/ci.yml` when the first code lands.

## Decisions log (newest first)

| Date | Decision | Where |
| --- | --- | --- |
| 2026-09-02 | Reference stack is Python/SQLite/FastAPI/htmx | ADR-0006 |
| 2026-09-02 | Adapters are the only per-app code and must pass the conformance suite | ADR-0005 |
| 2026-09-02 | Multi-user rollup is append-only JSONL committed to a git repo, aggregated by CI | ADR-0004 |
| 2026-09-02 | Three cost kinds: list, reported, effective (allocated + overage) | ADR-0003 |
| 2026-09-02 | Single canonical `usage_event` fact table plus a `measure` catalogue | ADR-0002 |
| 2026-09-02 | Local-first SQLite per user is the system of record | ADR-0001 |

## Open questions

| Id | Question | Owner | Blocking slice |
| --- | --- | --- | --- |
| Q-1 | Does the team want a hosted hub (long-running aggregator) or is the static rollup site enough? | owner | S6 |
| Q-2 | Which GitHub org(s) should the Copilot and billing collectors target, and who holds the token? | owner | S3 |
| Q-3 | Should CodeRabbit usage be derived from GitHub review events only, or is a CodeRabbit export available? | owner | S5 |
| Q-4 | Reporting currency per user or per team? (Design assumes team currency with per-user FX conversion.) | owner | S8 |

## Assumptions made in the design

- Every user runs Claude Code with hooks enabled and can enable OpenTelemetry export to localhost.
- GitHub personal access tokens with billing read scope are available per user; org-level tokens are optional.
- Subscription prices are entered manually; the tracker never has to scrape vendor pricing pages.
- Users are willing to commit usage exports (not transcripts) to a shared repo. Redaction levels are defined in SECURITY-PRIVACY.md.

## Research notes

Research notes live in `docs/00-context/research/`. One file per topic, named `<slice>-<topic>.md`.
Each note ends with a "What this changes" section that lists the documents updated.

| Note | Summary |
| --- | --- |
| [design-vendor-signals.md](research/design-vendor-signals.md) | Claude Code telemetry/hooks, GitHub billing and Copilot endpoints, CodeRabbit pricing, Anthropic Admin API, verified 2026-09-02 |

## Phase history

| Phase | Slice | Outcome | Context updated |
| --- | --- | --- | --- |
| 0 | Design | Architecture and delivery documents written | yes |

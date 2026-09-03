# CONTEXT.md — the living ledger

This file is the handoff between phases, people and AI sessions. It is deliberately short.
Anything that needs more than a paragraph gets its own document and a link from here.

**Rules**
1. Read this file before doing anything in any phase (research, design, build, test, redesign).
2. Update it as the last step of every phase. A phase is not done until this file says so.
3. Never delete history here. Mark items superseded and link the replacement.
4. Keep the "Current state" block accurate enough that a fresh session can continue with no other input.
5. Only the Fable session writes this file (ADR-0007). Builder sessions ask with `ask.sh`, record
   issues with `issue.sh` and log with `log.sh`; the next Fable session folds their output in here.

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
| Session protocol | Active: roles by model, 40-prompt limit, ledgers, hooks in `.claude/hooks/` (ADR-0007, SESSION-PROTOCOL.md) |
| PR author rule | `pr_author_login` = `newellnarco` in `.claude/hooks/policy.json`; repository Actions variable `PR_AUTHOR_LOGIN` set by the owner on 2026-09-03 |
| CI | Not installed yet. No workflow in `.github/workflows/`; `examples/ci/ci.yml` is the template to copy when S0 lands. Until then a Fable session reviews PRs but does not merge them unless the owner overrides |
| Branch protection on `main` | Not yet confirmed (owner action, next action 1) |
| Open PRs | [#1](https://github.com/newellnarco/SpendTracker/pull/1) design and session protocol (draft, author `newellnarco`, no CI to verify); this update is stacked on it |

## Next actions (owner and Fable)

1. **Owner:** enable branch protection on `main`: required checks `pr-author`, `lint`, `unit`, `integration`, `system`, `adapters`, `schema`, `build`; no direct pushes; no force pushes (SESSION-PROTOCOL.md "What the hooks cannot enforce", CI-CD.md). The `PR_AUTHOR_LOGIN` variable is already set.
2. **Owner:** decide whether PR #1 (and this stacked update) merges without CI, since no workflow exists yet to run the required checks (Q-5). Tell the next Fable session, which merges and records the override in the session log.
3. **Fable:** merge PR #1 once item 2 is decided. Then verify on a fresh start that the SessionStart hook classes a Fable session correctly; the hooks were authored on PR #1 and every session so far started before they were installed and needed the role override.

## Builder session queue

The Fable session writes one entry per end-to-end builder session and keeps this queue current.
A builder session takes the entry marked `in progress` for its branch when resuming, otherwise the
first `open` entry, and does the whole entry: reads what it lists, builds to the exit criteria,
fixes the issues it names, applies the answers it names, makes every change Fable requested, then
runs `/close-out`. Status values: open · in progress (branch, PR) · blocked (on a question or an
owner action) · done (merged commit). Entries are never deleted; done entries move to the bottom.

### BS-001 · open · S0 walking skeleton
- Slice: S0 (`02-delivery/VERTICAL-SLICES.md`)
- Branch: `work/s0-skeleton`
- Goal: a user can install the package, ingest one usage event from stdin, see a total on the CLI and in the browser.
- Read: `02-delivery/PHASE-PLAYBOOK.md`, `01-architecture/ARCHITECTURE.md` (§ layering), `01-architecture/DATA-MODEL.md`, `schema/001_core.sql`, ADR-0006, `02-delivery/CI-CD.md`.
- Scope: scaffold the Python package per ADR-0006; apply `schema/001_core.sql` on first run; `st ingest` reads canonical usage events from stdin; `st report` prints a single total; `st serve` shows the same total on one page. Copy `examples/ci/ci.yml` to `.github/workflows/ci.yml` in the same PR so `pr-author` and the tiers run from then on. Tag tests by tier (`unit`, `integration`, `system`); add a `blast-radius.yaml` entry for the new package.
- Exit criteria: the S0 exit criteria in VERTICAL-SLICES.md; `unit`, `integration` and `system` checks exist and pass on the PR; `st doctor` runs after `pipx install`.
- Fix issues: none assigned.
- Act on answers: none yet.
- Changes requested by Fable: none yet.
- Out of scope: collectors, pricing, rollup, any second page.

### BS-002 · open · CT and rollup workflows
- Slice: S0 follow-up (TESTING.md, AGGREGATION.md)
- Branch: `work/s0-workflows`
- Blocked by: BS-001 merged.
- Goal: nightly CT and the rollup workflow run from the repository, not from `examples/`.
- Read: `02-delivery/TESTING.md`, `02-delivery/CI-CD.md`, `01-architecture/AGGREGATION.md`, `examples/ci/ct-nightly.yml`, `examples/ci/rollup.yml`, `examples/ci/ci-issues.py`.
- Scope: install `ct-nightly.yml` and `rollup.yml` as workflows; wire `ci-issues.py` so failing tiers upload `ci-issues.jsonl` and post the PR comment described in CI-CD.md.
- Exit criteria: a deliberately failing test on a throwaway branch produces the artifact and the PR comment; the nightly runs green on `main`.
- Fix issues: none assigned.
- Act on answers: none yet.
- Changes requested by Fable: none yet.

## Decisions log (newest first)

| Date | Decision | Where |
| --- | --- | --- |
| 2026-09-03 | Repository Actions variable `PR_AUTHOR_LOGIN` set to `newellnarco`; the CI `pr-author` job is the enforcement path for PRs opened through the GitHub MCP tools | Owner action, recorded by the Fable session; Q-20260903-2afc |
| 2026-09-03 | CI runs tiered tests (unit, integration, system) selected by blast radius; failures feed `KNOWN-ISSUES.md`; full runs only for core, schema, workflow and dependency changes, `main`, `full-ci` and nightly | ADR-0008 |
| 2026-09-03 | Session roles are bound to the starting model and enforced by hooks: Fable reviews, answers, curates, merges and owns `CONTEXT.md`; other models build one piece per branch and PR; 40-prompt limit; PRs under the owner's username | ADR-0007 |
| 2026-09-02 | Reference stack is Python/SQLite/FastAPI/htmx | ADR-0006 |
| 2026-09-02 | Adapters are the only per-app code and must pass the conformance suite | ADR-0005 |
| 2026-09-02 | Multi-user rollup is append-only JSONL committed to a git repo, aggregated by CI | ADR-0004 |
| 2026-09-02 | Three cost kinds: list, reported, effective (allocated + overage) | ADR-0003 |
| 2026-09-02 | Single canonical `usage_event` fact table plus a `measure` catalogue | ADR-0002 |
| 2026-09-02 | Local-first SQLite per user is the system of record | ADR-0001 |

## Open questions

Design questions stay in this table. Session questions live in `QUESTIONS.md` (builders ask, Fable answers); only the ones still waiting on a human are mirrored here.

| Id | Question | Owner | Blocking slice |
| --- | --- | --- | --- |
| Q-1 | Does the team want a hosted hub (long-running aggregator) or is the static rollup site enough? | owner | S6 |
| Q-2 | Which GitHub org(s) should the Copilot and billing collectors target, and who holds the token? | owner | S3 |
| Q-3 | Should CodeRabbit usage be derived from GitHub review events only, or is a CodeRabbit export available? | owner | S5 |
| Q-4 | Reporting currency per user or per team? (Design assumes team currency with per-user FX conversion.) | owner | S8 |
| Q-5 | Merge PR #1 and the stacked CONTEXT.md update without CI, or wait for S0 to bring `ci.yml`? (next action 2) | owner | S0 |

Answered session questions: Q-20260903-2afc (PR author variable and branch protection), answered 2026-09-03; the branch-protection half is next action 1.

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

## Known issues

The ledger is `KNOWN-ISSUES.md`. Open entries: none. Fixed on 2026-09-03: I-20260903-cbb7 (this file was not updated for ADR-0007/0008 because the design session was classed as a builder by its own hooks).

## Phase history

| Phase | Slice | Outcome | Context updated |
| --- | --- | --- | --- |
| 0 | Design | Architecture and delivery documents written | yes |
| 0b | Design (session protocol) | ADR-0007, ADR-0008, SESSION-PROTOCOL.md, hooks, skills, ledgers, CI tiering examples on PR #1; session classed as builder so this file was left to the next Fable session (I-20260903-cbb7) | no (deferred to 0c) |
| 0c | Fable review | Q-20260903-2afc answered, I-20260903-cbb7 fixed, `PR_AUTHOR_LOGIN` recorded, builder session queue introduced (BS-001, BS-002); PR #1 not merged because the repo has no CI yet | yes |

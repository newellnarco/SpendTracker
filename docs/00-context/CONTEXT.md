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
| Active slice | S0 — Walking skeleton (packet written: `docs/tasks/BS-001-s0-walking-skeleton.md`; build not started) |
| Last completed slice | none |
| Schema version | 001 (designed, not applied) |
| Reference stack | Python 3.12, SQLite (WAL), FastAPI, htmx, Chart.js, Typer CLI (ADR-0006) |
| Local DB path | `~/.spendtracker/spend.db` |
| Rollup repo | to be created; layout in `01-architecture/AGGREGATION.md` |
| Reporting currency | USD (configurable, see COST-MODEL) |
| Session protocol | Active: role from the observed model, else declared, undeclared fails closed (ADR-0009); builder context is its packet, Fable holds the full context (ADR-0010); 40-prompt limit; ledgers; hooks in `.claude/hooks/`, self-test 89 checks (SESSION-PROTOCOL.md) |
| Process document | `docs/PROCESS.md`: division of labor and the task packet contract; SESSION-PROTOCOL.md keeps precedence on mechanics. Aligned across all documents on 2026-09-03 (phase 0e); the Word export in `docs/exports/` describes design, process and controls |
| Task packets | `docs/tasks/BS-nnn-<slug>.md`, one per builder session queue entry, written by Fable; the packet's acceptance criteria are what Fable verifies before merging |
| PR author rule | `pr_author_login` = `newellnarco` in `.claude/hooks/policy.json`; repository Actions variable `PR_AUTHOR_LOGIN` set by the owner on 2026-09-03 |
| CI | Not installed yet. No workflow in `.github/workflows/`; `examples/ci/ci.yml` is the template to copy when S0 lands. Until then a Fable session reviews PRs but does not merge them unless the owner overrides |
| Branch protection on `main` | Not yet confirmed. Importable rulesets are in `.github/rulesets/` (PR #4, merged 2026-09-03); the owner applies `main-protection.json` now and switches to the with-checks version after S0 (next action 1) |
| Open PRs | [#5](https://github.com/newellnarco/SpendTracker/pull/5) process reconciliation and the BS-001 packet (Fable); [#6](https://github.com/newellnarco/SpendTracker/pull/6) declared roles, superseded by ADR-0009 on this branch; the alignment-review PR from `claude/design-review-export-fsy8j1`, stacked on #5 (ADR-0009, ADR-0010, hooks, docs, Word export). [#1](https://github.com/newellnarco/SpendTracker/pull/1) to [#4](https://github.com/newellnarco/SpendTracker/pull/4) were merged on 2026-09-03 without CI by owner override (Q-5) |

## Next actions (owner and Fable)

1. **Owner:** apply `.github/rulesets/main-protection.json` (pull request required, no direct or force pushes, no required checks yet). After BS-001 merges and one PR has run `ci.yml` green, update the same ruleset to `main-protection-with-checks.json` (required checks `pr-author`, `lint`, `unit`, `integration`, `system`, `adapters`, `schema`, `build`). `PR_AUTHOR_LOGIN` is already set.
2. **Owner:** merge order: #5, then the alignment-review PR (stacked on #5, so it merges cleanly after it); close #6 unmerged, its fail-closed declaration model is carried into ADR-0009 with the model evidence kept. No CI exists yet, so both merges are owner overrides to log.
3. **Builder:** take BS-001 through its packet `docs/tasks/BS-001-s0-walking-skeleton.md`.
4. **Fable:** on a fresh start after the alignment PR merges, confirm the SessionStart hook now reports `role: undeclared` when the platform gives no model, that `ROLE: fable` in the first prompt binds it, and that the log line reads `fable (declared)`. Sessions `858bf604`, `ac98103e` and `475ebbee` all had to correct their state by hand (I-20260903-f7d2).
5. **Fable, after BS-001 closes out:** run every acceptance criterion in the packet on the PR head, review, merge when green, then write the BS-002 packet and ask the owner for the ruleset switch in item 1.

## Builder session queue

The Fable session writes one entry per end-to-end builder session and keeps this queue current.
A builder session takes the entry marked `in progress` for its branch when resuming, otherwise the
first `open` entry, and does the whole entry: reads what it lists, builds to the exit criteria,
fixes the issues it names, applies the answers it names, makes every change Fable requested, then
runs `/close-out`. Status values: open · in progress (branch, PR) · blocked (on a question or an
owner action) · done (merged commit). Entries are never deleted; done entries move to the bottom.

### BS-001 · open · S0 walking skeleton
- Packet: `docs/tasks/BS-001-s0-walking-skeleton.md`. Read it first; it expands this entry, lists the documents to read in order, and holds the seventeen acceptance criteria (AC-1 to AC-17) that Fable verifies before merging.
- Slice: S0 (`02-delivery/VERTICAL-SLICES.md`)
- Branch: `work/s0-skeleton`
- Goal: a user can install the package, ingest one usage event from stdin, see a total on the CLI and in the browser.
- Read: `02-delivery/PHASE-PLAYBOOK.md`, `01-architecture/ARCHITECTURE.md` (§ layering), `01-architecture/DATA-MODEL.md`, `schema/001_core.sql`, ADR-0006, `02-delivery/CI-CD.md`.
- Scope: scaffold the Python package per ADR-0006; apply `schema/001_core.sql` on first run; `st ingest` reads canonical usage events from stdin; `st add`, `st report` (single total), `st serve` (same total on one page), `st doctor` (minimal), `st adapter test --all` (stub so the CI `adapters` job passes with no adapters). Copy `examples/ci/ci.yml` to `.github/workflows/ci.yml` and add the `.github/actions/ci-issues` composite action it references, plus `tests/schema_snapshots/head.sql` for the `schema` job, in the same PR so `pr-author` and the tiers run from then on. Tag tests by tier (`unit`, `integration`, `system`); keep every module under a path mapped in `blast-radius.yaml`. Details, interfaces and file list: the packet.
- Exit criteria: AC-1 to AC-17 in the packet, which include the S0 exit criteria in VERTICAL-SLICES.md, the three tier checks passing on the PR head, and `st doctor` running after `pipx install`.
- Fix issues: none assigned.
- Act on answers: none yet.
- Changes requested by Fable: none yet.
- Out of scope: collectors, pricing, rollup, any second page.

### BS-002 · blocked · CT and rollup workflows
- Packet: to be written by the Fable session after BS-001 merges (its interfaces depend on the S0 package layout).
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
| 2026-09-03 | A session's role comes from the model the platform reports; when none is reported the session is undeclared and fails closed until it declares `ROLE: fable` or `ROLE: builder`; declared Fable roles are marked in the log and audited; model switches stay blocked | ADR-0009 (supersedes the role binding of ADR-0007 and PR #6) |
| 2026-09-03 | Only the Fable session holds the full context; a builder session gets `PROCESS.md`, its packet, the documents the packet lists and the start-hook excerpt, reads only its own packet (hook-enforced), and asks for anything else. Resolves Q-6 | ADR-0010 |
| 2026-09-03 | Cloud builder sessions push to the `claude/<slug>` branch the harness assigns; the packet's branch name applies to local sessions; Fable records the actual branch when the entry goes in progress | PROCESS.md § 8 |
| 2026-09-03 | Accepted PRs merge with a merge commit, never squash or rebase, so builder checkpoints and ledger entries survive | `/fable-review` step 6 |
| 2026-09-03 | Builder session queue entries are expanded into standalone task packets under `docs/tasks/`; a packet's acceptance criteria are what Fable verifies on the PR head before merging | `docs/PROCESS.md` § 3, `docs/tasks/BS-001-s0-walking-skeleton.md` |
| 2026-09-03 | `docs/PROCESS.md` (PR #3) records the division of labor between Fable and builder sessions; SESSION-PROTOCOL.md and the hooks keep precedence on mechanics until an ADR changes them | PR #3, reconciled by session `ac98103e` |
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
| Q-5 | Merge PR #1 and the stacked CONTEXT.md update without CI, or wait for S0 to bring `ci.yml`? Resolved 2026-09-03: the owner merged #1, #2, #3 and #4 without CI | owner (resolved) | S0 |
| Q-6 | How much context does a builder session receive? Resolved 2026-09-03 by the owner (asked twice: packet plus what it lists, for quality and security): ADR-0010; builder brief, SESSION-PROTOCOL.md, PROCESS.md and the phase playbook changed together | owner (resolved) | S0 (every builder session) |

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

The ledger is `KNOWN-ISSUES.md`. Open entries: none. Fixed on 2026-09-03: I-20260903-cbb7 (this file was not updated for ADR-0007/0008 because the design session was classed as a builder by its own hooks); I-20260903-f7d2 (the SessionStart hook receives no model in cloud sessions; fixed by ADR-0009).

## Phase history

| Phase | Slice | Outcome | Context updated |
| --- | --- | --- | --- |
| 0 | Design | Architecture and delivery documents written | yes |
| 0b | Design (session protocol) | ADR-0007, ADR-0008, SESSION-PROTOCOL.md, hooks, skills, ledgers, CI tiering examples on PR #1; session classed as builder so this file was left to the next Fable session (I-20260903-cbb7) | no (deferred to 0c) |
| 0c | Fable review | Q-20260903-2afc answered, I-20260903-cbb7 fixed, `PR_AUTHOR_LOGIN` recorded, builder session queue introduced (BS-001, BS-002); PR #1 not merged because the repo has no CI yet | yes |
| 0e | Fable (alignment review and export) | Every design, delivery and process document reviewed for alignment with the hooks, the packet and each other; ADR-0009 (role determination) and ADR-0010 (builder context boundary) written and implemented in the hooks with a 89-check self-test; SESSION-PROTOCOL.md rewritten with the session lifecycle, context boundary and gate diagrams; CI-CD, TESTING, VERTICAL-SLICES, PHASE-PLAYBOOK, PROCESS, GLOSSARY, READMEs and the skills aligned; Word export `docs/exports/` generated from the documents | yes |
| 0d | Fable (process and first packet) | `docs/PROCESS.md` reconciled with SESSION-PROTOCOL.md; first task packet BS-001 written under `docs/tasks/`; Q-5 resolved by the owner's merges of #1 to #4; Q-6 opened; rulesets from PR #4 recorded as next action 1 | yes |

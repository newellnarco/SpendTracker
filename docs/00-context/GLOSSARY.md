# Glossary

| Term | Meaning |
| --- | --- |
| **Layer / app** | One tool in the stack that costs money or consumes an allowance: Claude Code, Claude API, GitHub, GitHub Copilot, CodeRabbit, an MCP server, and so on. Stored in `app`. |
| **Measure** | The native unit a layer counts in. Examples: `token.input`, `token.cache_read`, `action.minute.linux`, `copilot.ai_credit`, `review.count`, `mcp.tool_call`, `session.count`, `active_time.s`. Stored in `measure`. |
| **Usage event** | One immutable fact: at time T, app A, under account X, in project P, session S, consumed quantity Q of measure M, with dimensions (model, sku, tool). Stored in `usage_event`. |
| **Dimension** | A tag on an event used for grouping: `model`, `sku`, `tool_name`, `mcp_server`, `actor`. |
| **Source** | Where an event came from: `hook`, `otlp`, `api`, `transcript`, `manual`, `import`. |
| **Node** | One installation of SpendTracker (one user on one machine). Provides provenance for rollups. |
| **Rate card** | Effective-dated price per unit of a measure for an app and optional sku/model. |
| **Subscription** | A flat-fee plan (Claude Max, Copilot Pro, CodeRabbit Pro seat, GitHub Team seat) with a period, price and optional included allowance. |
| **Coverage** | The selector on a subscription that says which events it pays for. |
| **List cost** | What an event would cost at pay-as-you-go rate-card prices. Always computable. |
| **Reported cost** | A currency amount the source itself supplied (Claude Code's `cost_usd_micros`, GitHub's `netAmount`). |
| **Allocated cost** | The share of a subscription's fee assigned to an event by an allocation method. |
| **Overage** | Usage beyond a subscription's included allowance, priced by the rate card. |
| **Effective cost** | The money the usage actually cost you: allocated + overage for covered events, list cost for uncovered events. |
| **Budget** | An amount per period for a scope (global, app, project, user, account) compared against effective cost. |
| **Cost line** | One derived money row per event per cost kind. Stored in `cost_line`. Recomputable at any time. |
| **Adapter** | The per-app module that discovers, collects and normalizes raw data into usage events. |
| **Collector run** | One execution of an adapter with a cursor before and after. Stored in `collector_run`. |
| **Spool** | A directory of small JSON files written by hooks; the ingester drains it. Decouples hooks from the DB. |
| **Export batch** | An append-only JSONL file of events from one node for one period, committed to the rollup repo. |
| **Rollup** | The aggregate database and dashboard built from all nodes' export batches. |
| **Capability** | A separately deliverable unit of functionality (C-xx in CAPABILITIES.md). |
| **Vertical slice** | An increment that cuts through collector, store, pricer, UI, tests and CI to deliver visible value (S-x in VERTICAL-SLICES.md). |
| **CT** | Continuous testing: scheduled test runs against recorded fixtures and live data invariants, independent of code pushes. |
| **Fable session** | The Claude Code session on the most capable model (`fable\|mythos`). Architect, reviewer and gate: answers questions, curates the ledgers, writes packets and `CONTEXT.md`, verifies CI, merges. Never writes code. (ADR-0007, ADR-0009) |
| **Builder session** | A Claude Code session on any other model. Builds one task packet on its own branch and draft PR, then stops. Never merges. (ADR-0007, ADR-0010) |
| **Undeclared session** | A session the platform reported no model for and that has not yet stated `ROLE: fable` or `ROLE: builder`. Carries every builder restriction. (ADR-0009) |
| **Task packet** | The standalone specification for one builder session: goal, reading list, acceptance criteria, interfaces, file list, checkpoints, tests. `docs/tasks/BS-nnn-<slug>.md`, written by Fable. (PROCESS.md § 3) |
| **Builder session queue** | The list of `BS-nnn` entries in `CONTEXT.md`, one per builder session, with status open / in progress / blocked / done. Fable writes it. |
| **Acceptance criterion (AC-n)** | A numbered, testable statement in a packet. The builder reports MET / NOT MET / UNVERIFIED with evidence; Fable runs every one on the PR head before merging. |
| **Checkpoint** | A step in a packet's build order that ends green and pushed, so a session that hits the prompt limit can hand over and the next session resumes there. |
| **Ledger** | One of the append-only files in `docs/00-context/`: `QUESTIONS.md`, `KNOWN-ISSUES.md`, `SESSION-LOG.md`, plus `CONTEXT.md`. Written only through the helper scripts by role. |
| **Close-out** | The last act of a builder session (`/close-out`): AC table, deviations, assumptions, spend; questions and issues filed; branch pushed; draft PR; `log.sh close`. |
| **Tier** | One of `unit`, `integration`, `system`: the marker every test carries and the named CI check it runs in. (ADR-0008) |
| **Blast radius** | The set of tiers and test selectors a changed path can affect, from `examples/ci/blast-radius.yaml`; CI runs that set instead of everything. (ADR-0008) |
| **Signature** | A short hash of check name and failure title that de-duplicates CI failures between `ci-issues.jsonl` and `KNOWN-ISSUES.md`. |
| **Context boundary** | The rule that only Fable holds the full context and a builder sees its packet plus what it lists. (ADR-0010) |

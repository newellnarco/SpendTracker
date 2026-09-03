# SpendTracker

Track spend in each layer's own currency (minutes, sessions, tokens, requests, actions, credits, reviews)
and translate it into money, across every tool in a developer stack: Claude Code, the Claude API,
GitHub (Actions, storage, seats), GitHub Copilot, CodeRabbit, MCP servers and any other AI or
platform integration you add later.

Everything runs locally first: collectors write to a per-user SQLite database and a local web UI
shows trends, usage by app, by measurement type, and by real currency after subscriptions and
budgets are factored in. Each user can export their data to a shared repository where a rollup job
aggregates all users into a team view.

## Status

This repository currently holds the **architecture and delivery design** and the **session
protocol** under which it is built. No application code has been written yet; the first packet
(S0 walking skeleton) is written and waiting for a builder session. Start at
[`docs/README.md`](docs/README.md).

## Repository map

| Path | What it is |
| --- | --- |
| `docs/00-context/` | The living context ledger (`CONTEXT.md`), glossary and Architecture Decision Records. Read first in every phase. |
| `docs/01-architecture/` | System architecture, data model (ERD), collectors and hooks per app, cost model, multi-user aggregation, web UI, adapter contract, security. |
| `docs/02-delivery/` | Separable capabilities, vertical slices, the per-phase playbook, testing, and CI/CD/CT. |
| `schema/` | SQLite DDL and seed data (rate cards, subscriptions, measures). |
| `examples/` | Reference hook scripts, OpenTelemetry collector config, rollup export samples, CI workflow templates, an adapter template. |
| `docs/PROCESS.md`, `docs/tasks/` | How work is divided between the Fable session (architect, reviewer, gate) and builder sessions (one task packet each), and the packets themselves. |
| `docs/exports/` | The Word export of the design, process and controls, regenerated from the documents. |
| `.claude/` | Session-protocol hooks, policy, role checklists (`/close-out`, `/fable-review`) and the hook self-test. |
| `.github/rulesets/` | Importable branch protection for `main`, the backstop the hooks cannot provide. |

## The one-paragraph design

Every app is a **layer**. Every layer emits **usage events** in its native **measure**
(`token.input`, `action.minutes`, `review.count`, `mcp.tool_call`, ...). Events land in one
canonical fact table in a local SQLite file. A **pricer** turns events into **cost lines** using
effective-dated **rate cards** and **subscriptions**, producing both a *list* cost (what the usage
would cost at pay-as-you-go prices) and an *effective* cost (the share of a flat subscription the
usage actually consumed, plus any overage). **Budgets** compare effective cost against allocations.
A local web UI renders all of it. **Adapters** are the only per-app code; adding a layer means adding
an adapter and a rate card, nothing else. **Export** produces append-only files that a shared repo
rolls up across users.

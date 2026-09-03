# SpendTracker documentation

## Reading order

1. [`00-context/CONTEXT.md`](00-context/CONTEXT.md) — the living ledger. Which slice is active, what has been decided, what is open. **Read this first in every phase, update it last in every phase.**
2. [`00-context/GLOSSARY.md`](00-context/GLOSSARY.md) — the vocabulary used everywhere else.
3. [`01-architecture/ARCHITECTURE.md`](01-architecture/ARCHITECTURE.md) — system overview, C4 views, UML.
4. [`01-architecture/DATA-MODEL.md`](01-architecture/DATA-MODEL.md) — ERD and table dictionary; DDL lives in [`../schema/001_core.sql`](../schema/001_core.sql).
5. [`01-architecture/COLLECTORS.md`](01-architecture/COLLECTORS.md) — integration points and hooks for each app.
6. [`01-architecture/COST-MODEL.md`](01-architecture/COST-MODEL.md) — measures to money, subscriptions, budgets, currency.
7. [`01-architecture/AGGREGATION.md`](01-architecture/AGGREGATION.md) — multi-user rollup to a repository.
8. [`01-architecture/WEB-UI.md`](01-architecture/WEB-UI.md) — local web interface and its API.
9. [`01-architecture/ADAPTER-SPEC.md`](01-architecture/ADAPTER-SPEC.md) — the contract for adding a new layer.
10. [`01-architecture/SECURITY-PRIVACY.md`](01-architecture/SECURITY-PRIVACY.md) — secrets, PII, redaction.
11. [`02-delivery/CAPABILITIES.md`](02-delivery/CAPABILITIES.md) — separable units of work.
12. [`02-delivery/VERTICAL-SLICES.md`](02-delivery/VERTICAL-SLICES.md) — the iterative build order.
13. [`02-delivery/PHASE-PLAYBOOK.md`](02-delivery/PHASE-PLAYBOOK.md) — how to run any phase without losing context.
14. [`02-delivery/TESTING.md`](02-delivery/TESTING.md) and [`02-delivery/CI-CD.md`](02-delivery/CI-CD.md).

## Architecture Decision Records

| ADR | Decision |
| --- | --- |
| [ADR-0001](00-context/adr/ADR-0001-local-sqlite-store.md) | Local-first SQLite as the system of record per user |
| [ADR-0002](00-context/adr/ADR-0002-canonical-usage-event.md) | One canonical usage-event fact table with a measure catalogue |
| [ADR-0003](00-context/adr/ADR-0003-list-vs-effective-cost.md) | Keep list cost, reported cost and effective (allocated) cost as separate cost kinds |
| [ADR-0004](00-context/adr/ADR-0004-git-backed-rollup.md) | Append-only file export rolled up through a git repository |
| [ADR-0005](00-context/adr/ADR-0005-adapter-plugin-contract.md) | Adapters are the only per-app code, bound by a conformance suite |
| [ADR-0006](00-context/adr/ADR-0006-implementation-stack.md) | Python, SQLite, FastAPI, htmx and Chart.js as the reference stack |

## Diagram index

All diagrams are Mermaid blocks rendered by GitHub. Search for the diagram id to find it.

| Id | Kind | Where |
| --- | --- | --- |
| `D-CTX` | C4 context | ARCHITECTURE.md |
| `D-CONT` | C4 container | ARCHITECTURE.md |
| `D-COMP` | Component (collector to UI) | ARCHITECTURE.md |
| `D-CLASS` | UML class model of the domain | ARCHITECTURE.md |
| `D-SEQ-HOOK` | Sequence: Claude Code hook to dashboard | ARCHITECTURE.md |
| `D-SEQ-PULL` | Sequence: scheduled API pull | ARCHITECTURE.md |
| `D-STATE` | State: collector run lifecycle | ARCHITECTURE.md |
| `D-ERD` | Entity relationship diagram | DATA-MODEL.md |
| `D-COST` | Cost derivation pipeline | COST-MODEL.md |
| `D-ROLLUP` | Multi-user rollup flow | AGGREGATION.md |
| `D-UI` | UI navigation map | WEB-UI.md |
| `D-SLICES` | Gantt of vertical slices | VERTICAL-SLICES.md |
| `D-CAPDEP` | Capability dependency graph | CAPABILITIES.md |
| `D-PIPE` | CI/CD/CT pipeline | CI-CD.md |

## Conventions

- Identifiers in prose use the exact slugs from the schema (`usage_event`, `token.input`).
- Money is always stored as integer micro-units with a currency code. Never store floats for money.
- Timestamps are UTC ISO-8601 in storage; the UI localizes.
- A document that changes a decision must add or supersede an ADR and add a line to `CONTEXT.md`.

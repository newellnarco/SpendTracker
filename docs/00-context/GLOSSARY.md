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

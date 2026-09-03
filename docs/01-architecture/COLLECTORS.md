# Collectors: integration points and hooks per layer

Each layer is integrated by an **adapter** (ADAPTER-SPEC.md). This document records, per layer,
where the data lives, which mechanism the adapter uses, what measures it emits, how it stays
idempotent, and what the known gaps are. Verified against vendor documentation on 2026-09-02;
re-verify in the research step of the slice that implements each adapter and record the note in
`docs/00-context/research/`.

## 0. Mechanisms

| Mechanism | Direction | Latency | Used by |
| --- | --- | --- | --- |
| **Hook** — the tool runs our script on an event; the script writes a spool file | push | seconds | Claude Code, any tool with lifecycle hooks |
| **OTLP receiver** — the tool exports OpenTelemetry logs/metrics to `127.0.0.1:4318` | push | seconds | Claude Code (richest source), other OTel-instrumented tools |
| **Transcript / log parsing** — read local files the tool already writes | pull (local) | minutes | Claude Code fallback, any CLI with JSONL logs |
| **Vendor API pull** — scheduled REST calls with the user's token | pull | hours to a day (vendor reporting lag) | GitHub billing, Copilot, Anthropic Admin API |
| **Derived from a neighbour** — count another system's records | pull | hours | CodeRabbit via GitHub PR reviews |
| **Proxy / shim** — wrap a process and count what passes through | push | seconds | MCP servers on hosts without hooks |
| **Import** — CSV/JSON files or manual entries via UI/CLI | manual | n/a | invoices, vendors without APIs |

Every mechanism ends in the same place: a `UsageEvent` envelope in the spool or a direct call to
`core.ingest`. See `examples/claude-code/spendtracker-hook.sh` for the envelope shape.

## 1. Claude Code

**Three complementary sources, ordered by preference.** All three can run at once; deduplication
by `source_ref` (`request_id`, `tool_use_id`, `session_id`) keeps counts correct.

### 1a. OpenTelemetry export (preferred for tokens and cost)

Enable in the user's shell profile or `~/.claude/settings.json` `env` block:

```bash
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=otlp
export OTEL_LOGS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_PROTOCOL=http/json
export OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4318
export OTEL_RESOURCE_ATTRIBUTES="spendtracker.node=alice-mbp"
```

`st serve` hosts the receiver at `/v1/logs` and `/v1/metrics`. A full OpenTelemetry Collector
config is in `examples/otel/collector-config.yaml` for users who already run one; it fans out to
SpendTracker and to their existing backend.

| OTel signal | Mapped measures | Dimensions | source_ref |
| --- | --- | --- | --- |
| log `claude_code.api_request` | `token.input`, `token.output`, `token.cache_read`, `token.cache_write`, `request.count`, `cost.reported.usd` (from `cost_usd_micros`) | `model`, `speed` (→ `sku`), `effort`, `agent.name`, `skill.name`, `mcp_server.name`, `mcp_tool.name` (→ attrs) | `request_id` |
| log `claude_code.tool_result` | `tool_call.count` or `mcp.tool_call` (when `mcp_server_name` set), `mcp.duration_ms` | `tool_name`, `mcp_server`, `success` | `tool_use_id` |
| log `claude_code.api_error` | `request.error` (registered by the adapter) | `model`, `status_code` | `request_id` + attempt |
| metric `claude_code.active_time.total` | `active_time.s` | `type` (user/cli) | session id + bucket timestamp |
| metric `claude_code.lines_of_code.count` | `loc.added` / `loc.removed` | `model` | session id + bucket timestamp |
| metric `claude_code.commit.count`, `pull_request.count` | `commit.count`, `pr.count` | | session id + bucket timestamp |
| metric `claude_code.session.count` | `session.count` | `start_type` | session id |

Standard attributes `session.id`, `user.account_uuid`, `organization.id`, `user.email` map to
`session`, `account` and `actor` (email is hashed unless the node config opts in to storing it).

Metrics arrive as cumulative sums; the receiver converts to deltas per `session.id` and drops the
first observation. Cost metrics (`claude_code.cost.usage`) are ignored when `api_request` events
are present, to avoid double counting.

### 1b. Hooks (preferred for sessions, projects and MCP tool calls; works with telemetry off)

Configure in `~/.claude/settings.json` (user scope) so every project is covered. Reference
configuration: `examples/claude-code/settings.hooks.json`. The script:
`examples/claude-code/spendtracker-hook.sh`.

| Hook event | What we record | Why this event |
| --- | --- | --- |
| `SessionStart` | `session.count = 1`; creates `session` with `model`, `cwd` → project, `session_start_reason` | Only reliable place to learn the project and model |
| `PostToolUse` (matcher `mcp__.*`) | `mcp.tool_call = 1`, `mcp.duration_ms = execution_time_ms`; `tool_name` parsed into `mcp_server` + tool | MCP usage per server without OTel |
| `PostToolUse` (matcher `*`, optional) | `tool_call.count = 1` for built-in tools | Actions per session; off by default to keep the spool small |
| `Stop` | `turn.count = 1` with `turn_number`, `stop_reason` | Turns per session |
| `SessionEnd` | closes `session` (`ended_at`, `turn_count`) and triggers a transcript parse (1c) for that session | Guarantees tokens are captured even without OTel |

Hook design constraints: exit 0 always; write one file per invocation; under 50 ms; no network;
never read the transcript synchronously except on `SessionEnd`, and then only spawn `st ingest
--transcript PATH --session ID` in the background (`async: true`).

### 1c. Transcript parsing (fallback and backfill)

`~/.claude/projects/<project-hash>/<session_id>.jsonl` contains assistant messages with
`message.usage` (`input_tokens`, `output_tokens`, `cache_creation_input_tokens`,
`cache_read_input_tokens`) and `message.model`. The adapter walks new lines since the stored byte
offset per file. `source_ref` is the message `uuid`. This also enables `st backfill claude-code`
for history before SpendTracker was installed. Transcript contents are never stored; only counts.

Known gaps: transcripts do not carry cost; the pricer supplies list cost from the rate card. Sub-agent
usage appears in the same file with `agent_id`; it is attributed to the parent session with
`attrs.agent_id`.

## 2. Claude API (direct application usage)

Two adapters, use whichever applies:

| Adapter | Mechanism | Measures | Notes |
| --- | --- | --- | --- |
| `anthropic_admin` | Pull `GET /v1/organizations/usage_report/messages` (`bucket_width=1d`, `group_by[]=model,api_key_id,workspace_id,service_tier`) and `GET /v1/organizations/cost_report` (`group_by[]=description`) with an Admin API key | `token.input` (uncached), `token.cache_read`, `token.cache_write` (sku `ephemeral_5m` / `ephemeral_1h`), `token.output`, `cost.reported.usd` | Org-level only; not available for individual accounts. Cursor = last complete day. `source_ref` = hash of (bucket, model, api_key_id, workspace_id, token_type). |
| `sdk_usage_log` | Push. A ten-line middleware in the application logs `response.usage` + `model` + `request_id` as a spool envelope (Python and TypeScript snippets in `examples/adapters/template/`) | same token measures, `request.count` | For apps you own. `source_ref` = `request_id`. |

Rate card seed for Anthropic first-party pricing is in `schema/seed/rate_cards.example.yaml`
(prices as of 2026-06-24 per the Claude platform pricing page; re-verify when seeding).

## 3. Claude subscriptions (Pro / Max) and Claude Code under them

Not a collector, a **subscription** row: plan, monthly price, coverage
`{"apps":["claude_code"],"measures":["token.*","request.count"]}`, `allocation_method:
usage_share`. Claude Code still reports `cost_usd`; it lands as `reported` cost while `effective`
cost is the allocated subscription share (ADR-0003). Rate limits ("5-hour windows") are not billed
units and are not modelled; a future adapter can record `ratelimit.hit` events from
`claude_code.api_error` with status 429.

## 4. GitHub platform (Actions, storage, Codespaces, seats)

| Item | Value |
| --- | --- |
| Mechanism | Pull, `GET /users/{username}/settings/billing/usage` (personal) and `GET /organizations/{org}/settings/billing/usage` (org), params `year`, `month`, `day`; `/usage/summary` for product/sku rollups |
| Token | Fine-grained PAT with "Plan" read (user) or org billing read; referenced by env var name in config |
| Measures | Per `usageItems[].unitType`: minutes → `action.minute.<os>` (sku kept verbatim, e.g. `Actions Linux`), GB-months → `storage.gb_month`, core-hours → `codespaces.core_hour`; `netAmount` → `cost.reported.usd`; `grossAmount − netAmount` → `attrs.discount_usd` |
| Attribution | `repositoryName` → `project`; `organizationName` → `account` |
| Idempotency | `source_ref` = sha256 of the canonical line (date, product, sku, repositoryName, unitType, quantity) |
| Cursor | last fully reported day; re-fetch the trailing 3 days each run because GitHub back-fills |
| Seats | `seat.count` snapshot per day from the plan endpoint or manual config; priced via a `github_team` subscription |
| Gaps | Included free minutes appear as `discountAmount`; the pricer treats netAmount as authoritative reported cost and list cost from the rate card shows the pre-discount value |

## 5. GitHub Copilot

GitHub moved Copilot to usage-based billing on 2026-06-01: plans include monthly **AI credits**,
usage is metered in tokens by model at listed rates, overage is paid. Pre-June history used
**premium requests**. Both are modelled; the measure tells you which regime a row belongs to.

| Item | Value |
| --- | --- |
| Mechanism (billing) | Pull `GET /users/{username}/settings/billing/ai_credit/usage` and `.../premium_request/usage` (legacy), params `year`, `month`, `day`, `model`, `product`; org variants under `/organizations/{org}/...` with an extra `user` filter |
| Measures | `copilot.ai_credit` (netQuantity), `copilot.premium_request` (legacy), `cost.reported.usd` (netAmount); when the response includes token detail it is emitted as `token.input`/`token.output` with `model` |
| Mechanism (metrics, org/enterprise) | Pull `GET /orgs/{org}/copilot/metrics/reports/users-1-day` and `organization-1-day`; the response gives signed `download_links`; the adapter downloads and parses per-user rows |
| Measures (metrics) | `copilot.suggestion.shown`, `copilot.suggestion.accepted`, `copilot.chat.turn`, `copilot.pr.summary`, `seat.count` (active users) |
| Subscription | `copilot_pro`, `copilot_pro_plus`, `copilot_business` (per seat) with `included_allowance: {"copilot.ai_credit": <plan credits>}`; overage rate card on `copilot.ai_credit` |
| Local IDE hook | none available. Gap accepted; VS Code shows usage in the status bar only. A future VS Code extension can post spool envelopes over the local HTTP ingest endpoint. |
| Idempotency | `source_ref` = sha256(date, product, sku, model, user) |

## 6. CodeRabbit

CodeRabbit exposes no usage API today (open question Q-3). The adapter derives usage from GitHub.

| Item | Value |
| --- | --- |
| Mechanism | Pull. For each configured repository: `GET /repos/{owner}/{repo}/pulls?state=all&sort=updated` since cursor, then `GET /repos/{owner}/{repo}/pulls/{n}/reviews` and `.../comments`; keep rows whose `user.login == "coderabbitai[bot]"` |
| Measures | `review.count` (one per review submission), `review.comment` (one per review comment), `pr.reviewed` (distinct PR per day) |
| Attribution | repository → `project`; PR author login → `actor` (seat billing is per developer who opens PRs) |
| Subscription | `coderabbit_pro` or `coderabbit_pro_plus` per seat; `included_allowance: {"review.count": <cap per developer>}` when the plan has a cap |
| Idempotency | `source_ref` = review id / comment id |
| Gaps | Reviews on non-GitHub hosts (GitLab, Azure DevOps) need a sibling adapter; Enterprise invoices go in `invoice` for reconciliation |

## 7. MCP servers

MCP usage is measured in **actions** (tool calls) and **time**; if a server is a paid SaaS its own
pricing is a rate card on `mcp.tool_call` filtered by `mcp_server`.

| Host | Mechanism | Notes |
| --- | --- | --- |
| Claude Code | Hook `PostToolUse` with matcher `mcp__.*` (1b) and/or OTel `tool_result` with `mcp_server_name` (1a) | `tool_name` is `mcp__<server>__<tool>`; the adapter splits it |
| Any stdio host (Cursor, other CLIs) | `st mcp-proxy -- <server command>`: a stdio proxy that forwards JSON-RPC unchanged and records `tools/call` requests and their response latency to the spool | Configure the host to launch the proxy instead of the server. Zero changes to the server. |
| HTTP/SSE servers | Reverse-proxy mode of the same command (`st mcp-proxy --http http://localhost:3000`) | |
| Server-side | Optional: an MCP server built with the `mcp-builder` patterns can POST usage envelopes to the local ingest endpoint | For servers you own |

Measures: `mcp.tool_call`, `mcp.duration_ms`, `mcp.error` (registered by adapter), `mcp.bytes.out`
(response size, optional). Dimensions: `mcp_server`, `tool_name`.

## 8. Other AI and SaaS layers (OpenAI, Gemini CLI, Codex CLI, Cursor, vendor MCP services)

Use the generic adapters until a dedicated one exists:

| Adapter | Mechanism | Typical use |
| --- | --- | --- |
| `csv_import` | `st import csv --mapping mapping.yaml file.csv` | Vendor usage exports |
| `manual` | `st add --app openai --measure token.output --qty 12000 --model gpt-x --at 2026-09-01` or the UI form | Small vendors, one-off costs |
| `sdk_usage_log` | Same envelope as §2 | Any application you control |
| `otlp_generic` | Any OTel log record with attributes `spendtracker.app`, `spendtracker.measure`, `spendtracker.quantity` | Instrumented internal tools |

A dedicated adapter is warranted once a layer is used daily; VERTICAL-SLICES.md S7 delivers the
scaffold that makes that a one-hour task.

## 9. Invoices (reconciliation input)

`st invoice add --app github --period 2026-08 --amount 42.17 --currency USD` or CSV import.
The Reconciliation page compares invoice totals with computed effective cost per app and period and
highlights differences above a configurable tolerance. Differences usually mean a missing rate
card, an uncollected day, or discounts the tracker cannot see.

## 10. Scheduling

| Platform | Setup |
| --- | --- |
| macOS | `st schedule install` writes `~/Library/LaunchAgents/dev.spendtracker.collect.plist` running `st collect --all` hourly |
| Linux | writes a systemd user timer `spendtracker-collect.timer` |
| Windows | Task Scheduler entry via `schtasks` |
| Any | `st serve --with-scheduler` runs collectors in-process while the UI is up |

Each run records a `collector_run` row; the Collectors page shows last success, lag and errors.

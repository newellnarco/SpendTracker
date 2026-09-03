# Architecture

## 1. Goals and constraints

| Goal | How the architecture meets it |
| --- | --- |
| Capture each layer's native measure (tokens, minutes, requests, sessions, actions, credits, reviews) | One fact table keyed by a measure catalogue (ADR-0002). |
| Translate to money including subscriptions and budgets | Pricer with rate cards, subscriptions, allocation and budgets (ADR-0003, COST-MODEL.md). |
| Store locally in SQLite | Per-node database, WAL, spool-based ingest (ADR-0001). |
| Local web UI for trends, by app, by type, by currency | FastAPI + htmx pages over SQL views (WEB-UI.md). |
| Roll up many local users to a repository | Append-only JSONL export, git-based rollup, CI-built aggregate (ADR-0004, AGGREGATION.md). |
| Add layers incrementally | Adapter contract and conformance suite (ADR-0005, ADAPTER-SPEC.md). |
| Iterate without losing context | Context ledger, ADRs, phase playbook (PHASE-PLAYBOOK.md). |

Non-goals for the first releases: real-time streaming dashboards, enforcing spend limits inside the
tools, and scraping vendor invoices from web portals.

## 2. System context (D-CTX)

```mermaid
flowchart LR
    dev([Developer])
    lead([Team lead / finance])

    subgraph Local machine
        st[SpendTracker node<br/>CLI + local web UI + SQLite]
    end

    subgraph Layers producing usage
        cc[Claude Code<br/>hooks, OTLP, transcripts]
        capi[Claude API / Admin API]
        gh[GitHub REST<br/>billing usage, PR reviews]
        cop[GitHub Copilot<br/>AI credit usage, metrics reports]
        cr[CodeRabbit<br/>reviews via GitHub]
        mcp[MCP servers<br/>tool calls via hooks or proxy]
        other[Other AI / SaaS<br/>API logs, CSV, manual]
    end

    rollup[(Rollup repository<br/>JSONL batches + CI + static dashboard)]

    cc -- push: hook JSON, OTLP events --> st
    capi -- pull: usage & cost reports --> st
    gh -- pull --> st
    cop -- pull --> st
    cr -- pull via GitHub --> st
    mcp -- push via hooks / proxy --> st
    other -- import --> st
    dev -- browses http://127.0.0.1:8787 --> st
    st -- st export, git push --> rollup
    lead -- browses team dashboard --> rollup
```

## 3. Container view (D-CONT)

```mermaid
flowchart TB
    subgraph node[SpendTracker node]
        direction TB
        spool[/Spool dir<br/>~/.spendtracker/spool/*.json/]
        otlp[OTLP receiver<br/>127.0.0.1:4318]
        cli[CLI  st<br/>ingest · collect · price · report · export · serve]
        adapters[Adapters<br/>claude_code · anthropic_admin · github_billing · copilot · coderabbit · mcp · manual · csv]
        ingest[Ingest service<br/>validate · dedupe · write]
        pricer[Pricer<br/>rate cards · subscriptions · allocation · budgets]
        db[(SQLite<br/>spend.db)]
        web[Web UI<br/>FastAPI + htmx + Chart.js]
        sched[Scheduler<br/>cron / launchd / systemd timer]
    end

    hooks[Claude Code hooks] --> spool
    ccotel[Claude Code OTel exporter] --> otlp
    spool --> ingest
    otlp --> ingest
    sched --> cli
    cli --> adapters --> ingest
    ingest --> db
    db --> pricer --> db
    db --> web
    cli -- export --> files[/data/<node>/<YYYY-MM>.jsonl/]
```

Process model: `st serve` is one process hosting the web UI, the OTLP receiver, the spool watcher
and (optionally) the scheduler. Every other command is a short-lived process that opens the same
SQLite file. Hooks are shell scripts that only write files; they finish in milliseconds and never
block Claude Code.

## 4. Component view of the data path (D-COMP)

```mermaid
flowchart LR
    raw[Raw payload<br/>hook JSON · OTLP log record · API response · transcript line · CSV row]
    norm["normalize()<br/>adapter code"]
    ue[UsageEvent DTOs]
    val[Validator<br/>measure registered? UTC? quantity >= 0? source_ref stable?]
    dedupe[Dedupe<br/>unique on app+source+source_ref+measure]
    write[(usage_event)]
    price[Pricer<br/>list · reported · allocated · overage]
    cl[(cost_line)]
    views[SQL views<br/>v_daily_cost · v_budget_status · v_session_summary]
    api[JSON API<br/>/api/v1/series ...]
    ui[Pages<br/>Overview · Trends · Apps · Types · Sessions · Budgets]

    raw --> norm --> ue --> val --> dedupe --> write --> price --> cl --> views --> api --> ui
```

## 5. Domain model (D-CLASS)

```mermaid
classDiagram
    class App {
        +app_id: str
        +display_name: str
        +vendor: str
        +category: AppCategory
    }
    class Measure {
        +measure_id: str
        +app_id: str?
        +unit_kind: UnitKind
        +display_unit: str
    }
    class UsageEvent {
        +event_id: ULID
        +occurred_at: datetime
        +quantity: Decimal
        +model: str?
        +sku: str?
        +tool_name: str?
        +mcp_server: str?
        +actor: str?
        +source: Source
        +source_ref: str?
        +attrs: JSON
    }
    class Session {
        +session_id: str
        +started_at: datetime
        +ended_at: datetime?
        +external_session_id: str
    }
    class Project {
        +project_id: str
        +repo_remote: str?
        +label: str
    }
    class Account {
        +account_id: str
        +external_id: str
        +label: str
    }
    class Node {
        +node_id: str
        +handle: str
    }
    class RateCard {
        +rate_id: str
        +sku_pattern: str
        +price_per_unit_nanos: int
        +currency: str
        +effective_from: date
        +effective_to: date?
    }
    class Subscription {
        +sub_id: str
        +plan: str
        +price_micros: int
        +period: Period
        +coverage: Selector
        +included_allowance: Map~measure,qty~
        +allocation_method: AllocationMethod
    }
    class CostLine {
        +cost_id: str
        +cost_kind: CostKind
        +amount_micros: int
        +currency: str
        +pricer_version: str
    }
    class Budget {
        +budget_id: str
        +scope_type: ScopeType
        +scope_id: str
        +period: Period
        +amount_micros: int
        +thresholds: list~float~
    }
    class Adapter {
        <<interface>>
        +discover() AdapterInfo
        +collect(cursor) RawBatch
        +normalize(raw) UsageEvent[]
        +health() Health
    }
    class Pricer {
        +price(events) CostLine[]
        +allocate(subscription, period)
    }

    App "1" --> "*" Measure
    App "1" --> "*" UsageEvent
    Account "1" --> "*" UsageEvent
    Project "1" --> "*" UsageEvent
    Session "1" --> "*" UsageEvent
    Node "1" --> "*" UsageEvent
    Measure "1" --> "*" UsageEvent
    UsageEvent "1" --> "*" CostLine
    RateCard "0..1" --> "*" CostLine
    Subscription "0..1" --> "*" CostLine
    App "1" --> "*" RateCard
    App "1" --> "*" Subscription
    Adapter ..> UsageEvent : produces
    Pricer ..> CostLine : produces
    Budget ..> CostLine : evaluates
```

## 6. Key flows

### 6.1 Claude Code hook to dashboard (D-SEQ-HOOK)

```mermaid
sequenceDiagram
    participant CC as Claude Code
    participant H as spendtracker-hook.sh
    participant SP as Spool dir
    participant IN as Ingest (st serve watcher or st ingest)
    participant DB as spend.db
    participant PR as Pricer
    participant UI as Web UI

    CC->>H: Stop / SessionEnd / PostToolUse JSON on stdin
    H->>SP: write <ulid>.json (event envelope) and exit 0
    Note over H: never blocks, never opens the DB
    IN->>SP: drain files (batch)
    IN->>IN: adapter claude_code.normalize()
    IN->>DB: INSERT usage_event (ignore duplicates)
    IN->>SP: move file to spool/done or delete
    PR->>DB: price new events → cost_line
    UI->>DB: SELECT from v_daily_cost
    UI-->>CC: (developer sees the session on the Overview page)
```

The same path handles OpenTelemetry: the OTLP receiver writes each `claude_code.api_request` and
`claude_code.tool_result` log record to the spool as an envelope with `source=otlp`.

### 6.2 Scheduled API pull (D-SEQ-PULL)

```mermaid
sequenceDiagram
    participant T as Timer (cron / launchd)
    participant CLI as st collect --all
    participant AD as github_billing adapter
    participant GH as GitHub REST
    participant DB as spend.db

    T->>CLI: run
    CLI->>DB: read adapter_state cursor (last day fetched)
    CLI->>AD: collect(cursor)
    AD->>GH: GET /users/{u}/settings/billing/usage?year&month&day
    GH-->>AD: usageItems[]
    AD->>AD: normalize → events (measure per sku, cost.reported.usd)
    AD-->>CLI: RawBatch + events + next cursor
    CLI->>DB: INSERT events (dedupe on source_ref = hash of line)
    CLI->>DB: write collector_run row + new cursor
    CLI->>DB: price new events
```

### 6.3 Collector run lifecycle (D-STATE)

```mermaid
stateDiagram-v2
    [*] --> Scheduled
    Scheduled --> Running: lock acquired
    Running --> Normalizing: raw fetched
    Normalizing --> Writing: events validated
    Writing --> Pricing: inserted (dups ignored)
    Pricing --> Succeeded
    Running --> Failed: auth / network / rate limit
    Normalizing --> Failed: contract violation
    Failed --> Scheduled: retry with backoff (cursor unchanged)
    Succeeded --> [*]
```

## 7. Layering rules

1. `core` (schema, ingest, pricer, views) knows nothing about any app.
2. `adapters/*` depend on `core.api` only, never on each other.
3. `web` depends on SQL views and `core.api`; it never calls adapters.
4. `cli` orchestrates; it contains no business logic.
5. `rollup` reuses `core` to import batches into a second database with the same schema.

## 8. Runtime layout on disk

```
~/.spendtracker/
  config.toml            # node handle, reporting currency, enabled adapters, tokens by env var name
  spend.db               # SQLite (WAL: spend.db-wal, spend.db-shm)
  spool/                 # incoming hook / OTLP envelopes
  spool/failed/          # envelopes that failed validation, kept for inspection
  raw/                   # optional raw payload archive (off by default)
  exports/               # JSONL batches ready to commit to the rollup repo
  adapters/              # drop-in adapters
  logs/
```

## 9. Cross-cutting concerns

| Concern | Approach |
| --- | --- |
| Idempotency | Stable `source_ref` per adapter; unique index; ULID `event_id`. |
| Time | Store UTC; the UI converts with the node's timezone. Daily buckets are computed in the reporting timezone chosen in config. |
| Money | Integer micros + currency code; FX table for reporting currency. |
| Secrets | Tokens are referenced by environment variable name in `config.toml`; never stored in the DB or exports. |
| Privacy | Redaction levels applied at export (SECURITY-PRIVACY.md). Transcripts never leave the machine. |
| Observability of the tracker | `collector_run` table, `/health` endpoint, `st doctor`. |
| Versioning | Schema version in `schema_migration`; `pricer_version` on cost lines; `adapter_api_version` in manifests. |

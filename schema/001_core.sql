-- SpendTracker core schema, migration 001.
-- SQLite 3.35+ (RETURNING, generated columns). Apply with: st migrate
-- Conventions: ids are TEXT (slugs or ULIDs); money is INTEGER micro-units + currency code;
-- timestamps are TEXT ISO-8601 UTC ('2026-09-02T14:03:00Z'); JSON columns hold TEXT.

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS schema_migration (
    version      INTEGER PRIMARY KEY,
    applied_at   TEXT NOT NULL,
    description  TEXT NOT NULL
);

-- ---------------------------------------------------------------- reference

CREATE TABLE IF NOT EXISTS node (
    node_id      TEXT PRIMARY KEY,               -- ULID generated at first run
    handle       TEXT NOT NULL UNIQUE,           -- human label used in export paths, e.g. 'alice-mbp'
    user_handle  TEXT NOT NULL,                  -- the person; several nodes can share it
    hostname_hash TEXT,                          -- sha256 of hostname, never the hostname itself
    timezone     TEXT NOT NULL DEFAULT 'UTC',
    created_at   TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS app (
    app_id       TEXT PRIMARY KEY,               -- 'claude_code', 'claude_api', 'github', 'copilot', 'coderabbit', 'mcp', ...
    display_name TEXT NOT NULL,
    vendor       TEXT NOT NULL,
    category     TEXT NOT NULL CHECK (category IN ('ai_assistant','ai_api','scm','ci','review','mcp','other')),
    enabled      INTEGER NOT NULL DEFAULT 1,
    created_at   TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS measure (
    measure_id   TEXT PRIMARY KEY,               -- 'token.input', 'action.minute.linux', 'mcp.tool_call'
    app_id       TEXT REFERENCES app(app_id),    -- NULL = generic measure usable by any app
    unit_kind    TEXT NOT NULL CHECK (unit_kind IN ('count','duration_s','bytes','currency')),
    display_unit TEXT NOT NULL,                  -- 'tokens', 'min', 'GB-month', 'USD'
    description  TEXT,
    is_cost      INTEGER NOT NULL DEFAULT 0      -- 1 for cost.reported.* measures
);

CREATE TABLE IF NOT EXISTS account (
    account_id   TEXT PRIMARY KEY,               -- ULID
    app_id       TEXT NOT NULL REFERENCES app(app_id),
    external_id  TEXT NOT NULL,                  -- GitHub login/org, Anthropic org id, email hash
    label        TEXT NOT NULL,
    attrs        TEXT NOT NULL DEFAULT '{}',
    UNIQUE (app_id, external_id)
);

CREATE TABLE IF NOT EXISTS project (
    project_id   TEXT PRIMARY KEY,               -- ULID
    repo_remote  TEXT,                           -- normalized 'github.com/org/repo'
    path_hash    TEXT,                           -- sha256 of local cwd for non-git dirs
    label        TEXT NOT NULL,
    attrs        TEXT NOT NULL DEFAULT '{}'
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_project_remote ON project(repo_remote) WHERE repo_remote IS NOT NULL;

CREATE TABLE IF NOT EXISTS session (
    session_id   TEXT PRIMARY KEY,               -- ULID
    app_id       TEXT NOT NULL REFERENCES app(app_id),
    node_id      TEXT NOT NULL REFERENCES node(node_id),
    project_id   TEXT REFERENCES project(project_id),
    external_session_id TEXT,                    -- Claude Code session_id, CI run id, ...
    started_at   TEXT NOT NULL,
    ended_at     TEXT,
    model        TEXT,
    attrs        TEXT NOT NULL DEFAULT '{}',
    UNIQUE (app_id, external_session_id)
);

-- ---------------------------------------------------------------- facts

CREATE TABLE IF NOT EXISTS usage_event (
    event_id     TEXT PRIMARY KEY,               -- ULID, time-ordered
    node_id      TEXT NOT NULL REFERENCES node(node_id),
    app_id       TEXT NOT NULL REFERENCES app(app_id),
    account_id   TEXT REFERENCES account(account_id),
    project_id   TEXT REFERENCES project(project_id),
    session_id   TEXT REFERENCES session(session_id),
    occurred_at  TEXT NOT NULL,
    occurred_day TEXT GENERATED ALWAYS AS (substr(occurred_at, 1, 10)) STORED,
    measure_id   TEXT NOT NULL REFERENCES measure(measure_id),
    quantity     REAL NOT NULL CHECK (quantity >= 0),   -- tokens/counts are integral; minutes, GB-months are not
    -- dimensions (promoted from attrs because the UI filters on them)
    model        TEXT,
    sku          TEXT,
    tool_name    TEXT,
    mcp_server   TEXT,
    actor        TEXT,                           -- user handle or bot login the usage is attributed to
    -- provenance
    source       TEXT NOT NULL CHECK (source IN ('hook','otlp','api','transcript','manual','import')),
    source_ref   TEXT,                           -- stable id from the source; required for automatic sources
    adapter_id   TEXT NOT NULL,
    ingested_at  TEXT NOT NULL,
    attrs        TEXT NOT NULL DEFAULT '{}'
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_event_source
    ON usage_event(app_id, source, source_ref, measure_id) WHERE source_ref IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_event_day_app     ON usage_event(occurred_day, app_id);
CREATE INDEX IF NOT EXISTS ix_event_measure_day ON usage_event(measure_id, occurred_day);
CREATE INDEX IF NOT EXISTS ix_event_session     ON usage_event(session_id);
CREATE INDEX IF NOT EXISTS ix_event_project_day ON usage_event(project_id, occurred_day);
CREATE INDEX IF NOT EXISTS ix_event_model       ON usage_event(app_id, model);

-- Optional forensic archive of raw payloads (off by default; see config raw_archive = true)
CREATE TABLE IF NOT EXISTS raw_payload (
    raw_id       TEXT PRIMARY KEY,               -- sha256 of payload
    adapter_id   TEXT NOT NULL,
    received_at  TEXT NOT NULL,
    payload      BLOB NOT NULL
);

-- ---------------------------------------------------------------- pricing

CREATE TABLE IF NOT EXISTS rate_card (
    rate_id      TEXT PRIMARY KEY,               -- slug, e.g. 'anthropic.claude-opus-5.token.input.2026-05'
    app_id       TEXT NOT NULL REFERENCES app(app_id),
    measure_id   TEXT NOT NULL REFERENCES measure(measure_id),
    sku_pattern  TEXT NOT NULL DEFAULT '*',      -- glob on model or sku, e.g. 'claude-opus-5', 'actions_linux', '*'
    price_per_unit_nanos INTEGER NOT NULL,       -- price for ONE unit in nano-currency (1e-9). $5.00/MTok -> 5000 nanos per token; cost lines are rounded to micros
    currency     TEXT NOT NULL DEFAULT 'USD',
    effective_from TEXT NOT NULL,                -- date
    effective_to TEXT,                           -- NULL = open
    tier         TEXT NOT NULL DEFAULT 'standard',   -- 'standard','batch','fast','priority' ...
    source_url   TEXT,
    notes        TEXT
);
CREATE INDEX IF NOT EXISTS ix_rate_lookup ON rate_card(app_id, measure_id, effective_from);

CREATE TABLE IF NOT EXISTS subscription (
    sub_id       TEXT PRIMARY KEY,
    app_id       TEXT NOT NULL REFERENCES app(app_id),
    account_id   TEXT REFERENCES account(account_id),
    plan         TEXT NOT NULL,                  -- 'claude_max_5x', 'copilot_pro_plus', 'coderabbit_pro', 'github_team'
    price_micros INTEGER NOT NULL,
    currency     TEXT NOT NULL DEFAULT 'USD',
    period       TEXT NOT NULL CHECK (period IN ('month','year')),
    seats        INTEGER NOT NULL DEFAULT 1,
    starts_at    TEXT NOT NULL,
    ends_at      TEXT,
    coverage     TEXT NOT NULL DEFAULT '{}',     -- JSON selector: {"apps":["claude_code"],"measures":["token.*"],"accounts":[...]}
    included_allowance TEXT NOT NULL DEFAULT '{}', -- JSON {"copilot.ai_credit": 1500, "review.count": 10}
    allocation_method TEXT NOT NULL DEFAULT 'usage_share'
                 CHECK (allocation_method IN ('usage_share','even_daily','weights','none')),
    allocation_weights TEXT NOT NULL DEFAULT '{}', -- JSON {"project:<id>": 0.6, "project:<id2>": 0.4}
    notes        TEXT
);

CREATE TABLE IF NOT EXISTS cost_line (
    cost_id      TEXT PRIMARY KEY,               -- ULID
    event_id     TEXT REFERENCES usage_event(event_id) ON DELETE CASCADE,  -- NULL for synthetic idle lines
    sub_id       TEXT REFERENCES subscription(sub_id),
    rate_id      TEXT REFERENCES rate_card(rate_id),
    cost_kind    TEXT NOT NULL CHECK (cost_kind IN ('list','reported','allocated','overage','idle')),
    amount_micros INTEGER NOT NULL,
    currency     TEXT NOT NULL,
    period_key   TEXT NOT NULL,                  -- 'YYYY-MM' the allocation period (equals occurred month for list/reported)
    occurred_day TEXT NOT NULL,
    app_id       TEXT NOT NULL,
    project_id   TEXT,
    computed_at  TEXT NOT NULL,
    pricer_version TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_cost_event ON cost_line(event_id);
CREATE INDEX IF NOT EXISTS ix_cost_day   ON cost_line(occurred_day, app_id, cost_kind);
CREATE INDEX IF NOT EXISTS ix_cost_period ON cost_line(period_key, sub_id);

CREATE TABLE IF NOT EXISTS fx_rate (
    base         TEXT NOT NULL,
    quote        TEXT NOT NULL,
    rate         REAL NOT NULL,                  -- 1 base = rate quote
    as_of        TEXT NOT NULL,                  -- date
    source       TEXT NOT NULL DEFAULT 'manual',
    PRIMARY KEY (base, quote, as_of)
);

CREATE TABLE IF NOT EXISTS budget (
    budget_id    TEXT PRIMARY KEY,
    scope_type   TEXT NOT NULL CHECK (scope_type IN ('global','app','project','account','user','category')),
    scope_id     TEXT,                           -- NULL for global
    period       TEXT NOT NULL CHECK (period IN ('day','week','month','quarter','year')),
    amount_micros INTEGER NOT NULL,
    currency     TEXT NOT NULL DEFAULT 'USD',
    thresholds   TEXT NOT NULL DEFAULT '[0.5,0.8,1.0]',   -- JSON fractions that raise alerts
    starts_at    TEXT NOT NULL,
    ends_at      TEXT,
    label        TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS budget_alert (
    alert_id     TEXT PRIMARY KEY,
    budget_id    TEXT NOT NULL REFERENCES budget(budget_id) ON DELETE CASCADE,
    period_key   TEXT NOT NULL,
    threshold    REAL NOT NULL,
    fired_at     TEXT NOT NULL,
    acknowledged_at TEXT,
    UNIQUE (budget_id, period_key, threshold)
);

-- ---------------------------------------------------------------- reconciliation

CREATE TABLE IF NOT EXISTS invoice (
    invoice_id   TEXT PRIMARY KEY,
    app_id       TEXT NOT NULL REFERENCES app(app_id),
    account_id   TEXT REFERENCES account(account_id),
    period_start TEXT NOT NULL,
    period_end   TEXT NOT NULL,
    amount_micros INTEGER NOT NULL,
    currency     TEXT NOT NULL,
    source       TEXT NOT NULL DEFAULT 'manual',
    lines        TEXT NOT NULL DEFAULT '[]',     -- JSON of vendor line items when available
    notes        TEXT
);

-- ---------------------------------------------------------------- operations

CREATE TABLE IF NOT EXISTS adapter_state (
    adapter_id   TEXT NOT NULL,
    key          TEXT NOT NULL,                  -- 'cursor', 'last_success_at', ...
    value        TEXT NOT NULL,
    updated_at   TEXT NOT NULL,
    PRIMARY KEY (adapter_id, key)
);

CREATE TABLE IF NOT EXISTS collector_run (
    run_id       TEXT PRIMARY KEY,
    adapter_id   TEXT NOT NULL,
    started_at   TEXT NOT NULL,
    finished_at  TEXT,
    status       TEXT NOT NULL CHECK (status IN ('running','succeeded','failed','skipped')),
    cursor_before TEXT,
    cursor_after TEXT,
    events_seen  INTEGER NOT NULL DEFAULT 0,
    events_inserted INTEGER NOT NULL DEFAULT 0,
    error        TEXT
);
CREATE INDEX IF NOT EXISTS ix_run_adapter ON collector_run(adapter_id, started_at);

CREATE TABLE IF NOT EXISTS export_batch (
    batch_id     TEXT PRIMARY KEY,
    node_id      TEXT NOT NULL REFERENCES node(node_id),
    period_key   TEXT NOT NULL,                  -- 'YYYY-MM'
    from_event_id TEXT,
    to_event_id  TEXT,
    event_count  INTEGER NOT NULL,
    file_path    TEXT NOT NULL,
    sha256       TEXT NOT NULL,
    redaction_level TEXT NOT NULL,
    exported_at  TEXT NOT NULL
);

-- ---------------------------------------------------------------- views

-- Effective cost per event: allocated+overage when a subscription covers it, else reported, else list.
CREATE VIEW IF NOT EXISTS v_event_cost AS
SELECT e.event_id, e.occurred_day, e.app_id, e.project_id, e.session_id, e.measure_id, e.model, e.sku,
       e.tool_name, e.mcp_server, e.actor, e.quantity,
       COALESCE(SUM(CASE WHEN c.cost_kind='list'      THEN c.amount_micros END), 0) AS list_micros,
       COALESCE(SUM(CASE WHEN c.cost_kind='reported'  THEN c.amount_micros END), 0) AS reported_micros,
       COALESCE(SUM(CASE WHEN c.cost_kind='allocated' THEN c.amount_micros END), 0) AS allocated_micros,
       COALESCE(SUM(CASE WHEN c.cost_kind='overage'   THEN c.amount_micros END), 0) AS overage_micros,
       CASE
         WHEN SUM(CASE WHEN c.cost_kind IN ('allocated','overage') THEN 1 END) > 0
              THEN COALESCE(SUM(CASE WHEN c.cost_kind IN ('allocated','overage') THEN c.amount_micros END),0)
         WHEN SUM(CASE WHEN c.cost_kind='reported' THEN 1 END) > 0
              THEN COALESCE(SUM(CASE WHEN c.cost_kind='reported' THEN c.amount_micros END),0)
         ELSE COALESCE(SUM(CASE WHEN c.cost_kind='list' THEN c.amount_micros END),0)
       END AS effective_micros,
       MAX(c.currency) AS currency
FROM usage_event e
LEFT JOIN cost_line c ON c.event_id = e.event_id
GROUP BY e.event_id;

CREATE VIEW IF NOT EXISTS v_daily_cost AS
SELECT occurred_day, app_id, project_id, model,
       SUM(list_micros) AS list_micros,
       SUM(reported_micros) AS reported_micros,
       SUM(allocated_micros) AS allocated_micros,
       SUM(overage_micros) AS overage_micros,
       SUM(effective_micros) AS effective_micros,
       MAX(currency) AS currency
FROM v_event_cost
GROUP BY occurred_day, app_id, project_id, model;

-- Idle subscription cost (fee not attributable to any event) per day.
CREATE VIEW IF NOT EXISTS v_daily_idle AS
SELECT occurred_day, app_id, SUM(amount_micros) AS idle_micros, MAX(currency) AS currency
FROM cost_line WHERE cost_kind='idle'
GROUP BY occurred_day, app_id;

CREATE VIEW IF NOT EXISTS v_daily_usage AS
SELECT occurred_day, app_id, measure_id, model, sku, mcp_server, tool_name,
       SUM(quantity) AS quantity, COUNT(*) AS events
FROM usage_event
GROUP BY occurred_day, app_id, measure_id, model, sku, mcp_server, tool_name;

CREATE VIEW IF NOT EXISTS v_session_summary AS
SELECT s.session_id, s.app_id, s.project_id, s.started_at, s.ended_at, s.model,
       COUNT(e.event_id) AS events,
       SUM(CASE WHEN e.measure_id LIKE 'token.%' THEN e.quantity END) AS tokens,
       SUM(CASE WHEN e.measure_id = 'mcp.tool_call' THEN e.quantity END) AS mcp_calls,
       SUM(v.effective_micros) AS effective_micros,
       SUM(v.list_micros) AS list_micros
FROM session s
LEFT JOIN usage_event e ON e.session_id = s.session_id
LEFT JOIN v_event_cost v ON v.event_id = e.event_id
GROUP BY s.session_id;

-- Budget consumption per budget and period. Effective cost is summed from v_event_cost plus idle lines,
-- filtered by scope. Periods other than 'month' are bucketed in code; this view serves the month case.
CREATE VIEW IF NOT EXISTS v_budget_status AS
SELECT b.budget_id, b.label, b.scope_type, b.scope_id, b.period, b.amount_micros, b.currency,
       substr(x.occurred_day, 1, 7) AS period_key,
       SUM(x.effective_micros) AS spent_micros
FROM budget b
JOIN (
    SELECT occurred_day, app_id, project_id, effective_micros FROM v_event_cost
    UNION ALL
    SELECT occurred_day, app_id, NULL AS project_id, idle_micros AS effective_micros FROM v_daily_idle
) x ON (b.scope_type = 'global'
        OR (b.scope_type = 'app'     AND x.app_id     = b.scope_id)
        OR (b.scope_type = 'project' AND x.project_id = b.scope_id))
WHERE b.period = 'month'
  AND x.occurred_day >= b.starts_at
  AND (b.ends_at IS NULL OR x.occurred_day <= b.ends_at)
GROUP BY b.budget_id, substr(x.occurred_day, 1, 7);

INSERT OR IGNORE INTO schema_migration(version, applied_at, description)
VALUES (1, strftime('%Y-%m-%dT%H:%M:%SZ','now'), 'core schema');

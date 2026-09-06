-- SpendTracker findings and proposals, migration 002 (designed 2026-09-06, ADR-0011, FINDINGS.md).
-- Derived, recomputable rows. Human state (status, notes, applied_*) attaches to `signature`.

CREATE TABLE IF NOT EXISTS finding (
    finding_id    TEXT PRIMARY KEY,               -- ULID
    signature     TEXT NOT NULL UNIQUE,           -- sha256(rule_id, scope_type, scope_key, period_key, discriminator)
    rule_id       TEXT NOT NULL,                  -- 'gha.sweep_dispatch', 'sub.low_utilization'
    rule_pack     TEXT NOT NULL,                  -- adapter id or 'core'
    app_id        TEXT REFERENCES app(app_id),
    scope_type    TEXT NOT NULL CHECK (scope_type IN ('project','app','account','session','subscription','workflow','actor','global')),
    scope_key     TEXT NOT NULL,                  -- 'github.com/org/repo', 'github.com/org/repo#.github/workflows/ci.yml', sub_id, ...
    period_key    TEXT NOT NULL,                  -- 'YYYY-MM' or 'YYYY-MM-DD..YYYY-MM-DD'
    severity      TEXT NOT NULL CHECK (severity IN ('info','minor','major','critical')),
    kind          TEXT NOT NULL DEFAULT 'waste' CHECK (kind IN ('waste','risk','gap')),
    title         TEXT NOT NULL,
    detail        TEXT NOT NULL,
    measure_id    TEXT REFERENCES measure(measure_id),
    waste_quantity REAL,                          -- avoidable quantity in the measure's unit
    waste_micros  INTEGER,                        -- priced with the events' rate card or reported share
    currency      TEXT,
    evidence      TEXT NOT NULL DEFAULT '{}',     -- JSON: counterfactual, event/session ids, grouped numbers, windows
    status        TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','accepted','dismissed','resolved')),
    status_note   TEXT,
    first_seen_at TEXT NOT NULL,
    last_seen_at  TEXT NOT NULL,
    engine_version TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_finding_scope  ON finding(scope_type, scope_key, period_key);
CREATE INDEX IF NOT EXISTS ix_finding_status ON finding(status, severity);

CREATE TABLE IF NOT EXISTS proposal (
    proposal_id   TEXT PRIMARY KEY,               -- ULID
    finding_id    TEXT NOT NULL REFERENCES finding(finding_id) ON DELETE CASCADE,
    template_id   TEXT NOT NULL,                  -- from the rule manifest, e.g. 'sweep_skip_stale_drafts'
    title         TEXT NOT NULL,
    action        TEXT NOT NULL,                  -- what to change, prose; may include patch hints
    effort        TEXT NOT NULL CHECK (effort IN ('trivial','small','medium','large')),
    risk_note     TEXT,
    est_saving_quantity REAL,                     -- per period, in finding.measure_id units
    est_saving_micros   INTEGER,
    currency      TEXT,
    basis         TEXT NOT NULL CHECK (basis IN ('measured','extrapolated','assumed')),
    window_start  TEXT,                           -- measured window the estimate extrapolates from
    window_end    TEXT,
    overlaps_with TEXT NOT NULL DEFAULT '[]',     -- JSON list of proposal_ids explaining the same seconds
    status        TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','accepted','applied','verified','dismissed')),
    status_note   TEXT,
    applied_at    TEXT,
    applied_ref   TEXT,                           -- commit or PR URL
    verification  TEXT,                           -- JSON {before, after, delta, measured_at}
    updated_at    TEXT NOT NULL,
    UNIQUE (finding_id, template_id)
);
CREATE INDEX IF NOT EXISTS ix_proposal_status ON proposal(status);

-- Ranked view for the Findings page and `st findings list`.
CREATE VIEW IF NOT EXISTS v_proposal_ranked AS
SELECT p.proposal_id, p.finding_id, f.rule_id, f.rule_pack, f.app_id, f.scope_type, f.scope_key,
       f.period_key, f.severity, f.kind, f.title AS finding_title, p.title AS proposal_title,
       p.effort, p.basis, p.est_saving_quantity, f.measure_id, p.est_saving_micros, p.currency,
       p.status AS proposal_status, f.status AS finding_status, f.last_seen_at
FROM proposal p
JOIN finding f ON f.finding_id = p.finding_id
WHERE p.status IN ('open','accepted','applied')
ORDER BY p.est_saving_micros DESC, p.est_saving_quantity DESC;

INSERT OR IGNORE INTO schema_migration(version, applied_at, description)
VALUES (2, strftime('%Y-%m-%dT%H:%M:%SZ','now'), 'findings and proposals');

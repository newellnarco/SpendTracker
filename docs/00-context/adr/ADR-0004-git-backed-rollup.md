# ADR-0004: Append-only export files rolled up through a git repository

**Status:** Accepted — 2026-09-02

## Context

Multiple users on separate machines must contribute to one team view. The team already lives in
GitHub. A hosted database would add infrastructure, secrets and an availability dependency to a
tool whose primary value is local.

## Decision

- `st export` writes append-only JSONL batches per node per month:
  `data/<node_handle>/<YYYY>/<YYYY-MM>.jsonl` plus a manifest with counts and a SHA-256.
- Batches are committed to a rollup repository (a dedicated repo or a `spend/` directory in an
  existing one) through a pull request or a direct push to a per-user branch, whichever the team
  prefers.
- A CI workflow in the rollup repo validates the JSON schema on every PR and, on merge, rebuilds
  `rollup.db` (same schema as the local DB plus `node`) and publishes a static dashboard.
- Events are identified by ULID `event_id`; the rollup is idempotent and re-runnable from scratch.
- Rate cards, subscriptions and budgets for the team live in the rollup repo as YAML and are
  applied on rebuild, so every node prices the same way.

## Consequences

- Rollup latency is "whenever people push", which matches how budgets are reviewed.
- Data volume: 100k events per user per month at about 300 bytes each is 30 MB before git
  compression. Retention rules (AGGREGATION.md) and optional daily pre-aggregation keep this in
  bounds.
- A hosted hub (a long-running SpendTracker instance that imports batches) stays possible; it is the
  same import path. Tracked as open question Q-1.

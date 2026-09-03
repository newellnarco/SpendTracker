# ADR-0001: Local-first SQLite as the per-user system of record

**Status:** Accepted — 2026-09-02

## Context

Usage data is produced on each developer's machine (hooks, transcripts, OpenTelemetry events) and
by pulling vendor APIs with that developer's credentials. The requirement is a local web view with
no server dependency, plus the ability to roll up many users into one repository later.

## Decision

Each installation owns one SQLite database at `~/.spendtracker/spend.db` (override with
`SPENDTRACKER_DB`). It is the system of record for that node. WAL mode is on. All writes go through
the ingest layer; hooks never open the database directly, they write to a spool directory.

## Consequences

- Zero infrastructure for the single-user case. The UI reads the same file.
- Concurrency is bounded by SQLite's single-writer model. The spool plus a single ingester process
  make this a non-issue for the write rates involved (hundreds of events per minute at most).
- Rollup needs an explicit export format (ADR-0004) because SQLite files are not mergeable.
- Backups are file copies. `st backup` uses the SQLite online backup API.
- Schema evolution uses numbered SQL migration files under `schema/` applied by `st migrate`.
  Migrations are forward-only; a down migration is a new forward migration.

## Alternatives considered

- DuckDB: excellent analytics, weaker write concurrency story and larger binary. Kept as an
  optional analytics engine for the rollup (reads the exported JSONL directly).
- Postgres: contradicts the local-first requirement.

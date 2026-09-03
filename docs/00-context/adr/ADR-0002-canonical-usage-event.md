# ADR-0002: One canonical usage-event fact table with a measure catalogue

**Status:** Accepted — 2026-09-02

## Context

Layers count in different units and expose them differently: Claude Code emits token counts and a
reported USD cost per API request; GitHub bills minutes and gigabyte-months with a SKU; Copilot now
bills AI credits by model; CodeRabbit is per-seat with a review cap; MCP servers are counted in tool
calls. A design that adds a table per app would make every cross-app view a union of bespoke queries
and make "add a layer" a schema change.

## Decision

- A single fact table `usage_event` stores every observation as `(occurred_at, app, account,
  project, session, measure, quantity, dimensions, source, source_ref)`.
- `measure` is a catalogue table. Adapters register the measures they emit. A measure has a
  `unit_kind` (`count`, `duration_s`, `bytes`, `currency`) so the UI can format it.
- Currency amounts supplied by a source are stored as events too, with measures of unit kind
  `currency` (for example `cost.reported.usd`). The pricer copies them into `cost_line` rows of kind
  `reported`.
- Free-form extra fields go into `attrs` (JSON). Anything that becomes a filter in the UI is promoted
  to a real column by a migration.
- Idempotency key: `(app_id, source, source_ref, measure_id)` is unique when `source_ref` is not
  null. Adapters must supply a stable `source_ref` (request id, GitHub usage line hash, transcript
  message uuid).

## Consequences

- Adding a layer means inserting rows into `app` and `measure` and shipping an adapter. No DDL.
- The fact table is tall and narrow; SQLite handles tens of millions of rows with the indexes in
  `001_core.sql`.
- Some precision is lost by not modelling app-specific structure. The `attrs` JSON and the
  `raw_payload` archive (optional, off by default) cover forensic needs.

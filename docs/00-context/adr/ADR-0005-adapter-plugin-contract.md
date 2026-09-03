# ADR-0005: Adapters are the only per-app code and must pass a conformance suite

**Status:** Accepted — 2026-09-02

## Context

The stack will keep growing (new AI assistants, new MCP servers, new vendors). Each addition must
be cheap and must not destabilize what exists.

## Decision

- An adapter is a directory with `adapter.yaml` (manifest: id, app, measures, default rate cards,
  config schema, capabilities) and a module implementing the interface in ADAPTER-SPEC.md:
  `discover()`, `collect(cursor)`, `normalize(raw) -> UsageEvent[]`, `health()`.
- Adapters are discovered from the built-in package, from `~/.spendtracker/adapters/`, and from
  Python entry points in group `spendtracker.adapters`.
- Every adapter ships fixtures (`fixtures/raw/*.json`) and expected output
  (`fixtures/expected/*.jsonl`). The shared conformance suite replays them and checks the contract:
  stable `source_ref`, registered measures only, UTC timestamps, idempotent re-normalization.
- Core code never branches on an app id.

## Consequences

- "Add a layer" is a documented, testable, one-directory task (VERTICAL-SLICES.md S7 targets under
  one hour for a pull-style API adapter).
- The core must expose a small, stable API to adapters and version it (`adapter_api_version`).

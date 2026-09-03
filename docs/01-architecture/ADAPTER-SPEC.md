# Adapter specification: adding a layer

An adapter is the only code that knows about a specific app. Adding a new layer (a new AI tool, a
vendor MCP service, another CI provider) means writing one adapter directory and, usually, one rate
card. Nothing in `core`, `web` or `rollup` changes.

## 1. Directory layout

```
adapters/<adapter_id>/
  adapter.yaml            # manifest
  __init__.py             # implements the interface
  fixtures/
    raw/*.json            # recorded source payloads (redacted)
    expected/*.jsonl      # events the normalizer must produce
  README.md               # setup: tokens, scopes, known gaps
```

Locations searched, in order: built-in package, `~/.spendtracker/adapters/`, Python entry points in
group `spendtracker.adapters`.

## 2. Manifest

```yaml
adapter_api_version: 1
id: coderabbit
app:
  app_id: coderabbit
  display_name: CodeRabbit
  vendor: CodeRabbit
  category: review
  color: "#E8562A"
mechanism: pull            # pull | push | proxy | import
schedule: "0 * * * *"      # suggested cadence for pull adapters
measures:
  - id: review.count
    unit_kind: count
    display_unit: reviews
  - id: review.comment
    unit_kind: count
    display_unit: comments
config_schema:             # JSON Schema for the adapter's section of config.toml
  type: object
  required: [repos, github_token_env]
  properties:
    repos: {type: array, items: {type: string}}
    github_token_env: {type: string}
default_rate_cards: []     # optional; seat plans are subscriptions, not rate cards
default_subscriptions:
  - plan: coderabbit_pro
    period: month
    price: 24.00
    currency: USD
    coverage: {apps: [coderabbit]}
    included_allowance: {review.count: 0}
capabilities: [backfill, health]
```

## 3. Interface

```python
from spendtracker.core.api import (
    Adapter, AdapterInfo, RawBatch, UsageEvent, Cursor, Health, Context
)

class CodeRabbitAdapter(Adapter):
    def discover(self, ctx: Context) -> AdapterInfo:
        """Return manifest-derived info plus anything learned at runtime
        (e.g. the list of repos the token can see). Must not raise on missing config."""

    def collect(self, ctx: Context, cursor: Cursor | None) -> RawBatch:
        """Fetch raw data newer than cursor. Return raw payloads + next cursor.
        Must be safe to call repeatedly with the same cursor (idempotent at the source)."""

    def normalize(self, ctx: Context, raw: RawBatch) -> list[UsageEvent]:
        """Pure function. No I/O. Produces canonical events with stable source_ref."""

    def health(self, ctx: Context) -> Health:
        """Cheap check: token present, endpoint reachable, last run age."""
```

`UsageEvent` fields mirror `usage_event` columns. The core assigns `event_id`, `node_id`,
`ingested_at` and resolves `project_id`, `account_id`, `session_id` from the string keys the
adapter provides (`project_key = "github.com/org/repo"`, `account_key = "github:login"`,
`session_key = "<external id>"`).

`Context` gives adapters: config section, secret lookup by env var name, an HTTP client with
retries and rate-limit handling, a logger, the node timezone, and `ctx.now()` for testability.

Push adapters (hooks, OTLP, proxy) implement only `normalize` and `health`; the core feeds them
envelopes from the spool.

## 4. Contract (enforced by the conformance suite)

| Rule | Check |
| --- | --- |
| Every emitted `measure_id` is declared in the manifest or is a generic measure | static + runtime |
| `occurred_at` is timezone-aware UTC | runtime |
| `quantity ≥ 0` and finite | runtime |
| `source_ref` is non-null for `source ∈ {hook, otlp, api, transcript}` and is stable across two normalizations of the same raw payload | fixtures replayed twice, diff must be empty |
| `normalize` performs no I/O | run under a socket-less sandbox |
| `collect` with the returned cursor yields no already-seen events | recorded HTTP fixtures (respx / VCR) |
| Money supplied by the source is emitted as `cost.reported.<currency>` events, never converted by the adapter | static check on measure ids |
| Manifest validates against `schema/adapter-manifest.schema.json` | CI |
| README documents required scopes and known gaps | CI checks headings exist |

Run locally: `st adapter test <adapter_id>`; the same command runs in CI for every adapter.

## 5. Scaffold

`st adapter new <id> --mechanism pull` creates the directory from `examples/adapters/template/`
with a passing conformance test and a TODO list. Target: a pull adapter for a simple REST usage
endpoint in under one hour, including fixtures.

## 6. Out-of-process adapters

Adapters in other languages (a VS Code extension, a Go MCP proxy) write envelopes to the spool or
`POST /api/v1/ingest`. They still ship an `adapter.yaml` (for measures and app registration) and
fixtures; the conformance suite replays their envelopes through the generic `envelope` normalizer.

Envelope shape (one JSON object per file or array element):

```json
{"v":1,"adapter":"vscode_copilot","app":"copilot","occurred_at":"2026-09-02T14:03:11Z",
 "measure":"copilot.suggestion.accepted","quantity":1,"source":"hook","source_ref":"evt_9f2...",
 "project_key":"github.com/acme/api","session_key":"vscode:1234","model":"gpt-x","attrs":{}}
```

## 7. Versioning

`adapter_api_version` in the manifest is checked against the core at load time. The core supports
the current and previous major version. Breaking changes to `UsageEvent` or `Context` bump the
major version and ship a migration note in CONTEXT.md.

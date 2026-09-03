# ADR-0006: Reference implementation stack

**Status:** Accepted — 2026-09-02

## Decision

| Concern | Choice | Why |
| --- | --- | --- |
| Language | Python 3.12 | Fast to write adapters, ubiquitous on developer machines, first-class SQLite. |
| Packaging | `uv` project, published as a wheel; installed with `pipx install spendtracker` or `uv tool install` | One command install, one command upgrade (this is the "CD to local machine"). |
| CLI | Typer (`st` command) | Subcommands map one-to-one to capabilities. |
| Store | SQLite via the standard library `sqlite3`, WAL mode, hand-written SQL migrations | No ORM to fight; queries are the product. |
| Web | FastAPI + Jinja2 + htmx + Chart.js (vendored, no CDN) | Server-rendered pages, partial updates, offline-capable. |
| OTLP receiver | Minimal FastAPI route accepting OTLP/HTTP JSON logs and metrics on `127.0.0.1:4318` | Avoids running a separate collector for the common case; a full collector config is still provided in `examples/otel/`. |
| Scheduling | `st collect --all` run by cron, launchd or a systemd user timer; `st serve` also runs an in-process scheduler when asked | No daemon requirement. |
| Testing | pytest, hypothesis (property tests), Playwright (UI smoke), sqlite3 invariants | See TESTING.md. |
| Lint/type | ruff, mypy (strict for core, lenient for adapters) | |
| Rollup analytics | DuckDB reading exported JSONL, optional | Fast ad-hoc queries over all users. |

## Alternatives

- Go single binary: better distribution, slower adapter authoring. Revisit if install friction
  becomes the main complaint.
- TypeScript/Node: natural for VS Code extension work (a future Copilot local collector), but the
  data and pricing core is better served by Python's SQLite and numeric ecosystem. An adapter
  written in another language can still participate by writing spool files (ADAPTER-SPEC.md,
  "out-of-process adapters").

# BS-001 · S0 walking skeleton

| Field | Value |
| --- | --- |
| ROLE / AUTHOR | fable · session `ac98103e-96d1-5342-b6b7-982cd19f151f` (claude-fable-5-1) · 2026-09-03 |
| SPEC-COMMIT | `main` at `7fcb45b` (docs, `schema/`, `examples/` as of that commit) |
| PHASE / SLICE | Phase 1 (first build phase) · S0 (`docs/02-delivery/VERTICAL-SLICES.md`) |
| BRANCH | `work/s0-skeleton` for a local session; a cloud session pushes to the `claude/<slug>` branch the harness assigned it (PROCESS.md § 8) |
| CAPABILITIES | C-01, C-02 (stdin only), C-04, C-05 (list only), C-10 (Overview, one total), C-29 (minimal), C-30 (wheel) |
| STATUS | open (queue entry BS-001 in `docs/00-context/CONTEXT.md`) |

## 0. How to use this packet

- You are a **builder session**. Read `docs/PROCESS.md`, then this file, then the documents in
  section 2 in the order given. Nothing else is required to build this packet, and nothing else
  is in your context by design (ADR-0010): other packets are hook-denied, and anything this packet
  lacks is asked for with `ask.sh`.
- Work on the branch this session was started on (locally: `work/s0-skeleton` from `main`; in
  the cloud: the `claude/<slug>` branch you were given). Push early and open a **draft PR under
  the owner's GitHub username** (hard rule, `docs/02-delivery/SESSION-PROTOCOL.md`). Never merge.
- Build in the order of section 6. Each step ends with a green local check, so a session that
  reaches the 40-prompt limit can `/close-out` and the next builder resumes the entry marked
  `in progress`.
- Questions go through `.claude/hooks/ask.sh --session <sid> "question" --context "what depends on it"`.
  If the answer blocks you: log, close out, stop. If it does not: record the assumption with
  `log.sh progress`, continue, and list it in the close log.
- Progress: `.claude/hooks/log.sh --session <sid> progress "BS-001: ..."`. Every defect or CI
  failure you see: `.claude/hooks/issue.sh`. End with `/close-out`.

## 1. Goal

Prove the spine. After this packet a user can install SpendTracker from a wheel, initialise a
local SQLite database, put one usage event in from the command line or from stdin, see its list
cost on the CLI, and see the same number on one web page. CI runs on every PR from this point on.

The slice exit criterion, verbatim from VERTICAL-SLICES.md S0:

```
pipx install <wheel built in CI>
st add --app claude_api --measure token.output --qty 1000 --model claude-opus-5
st report          # prints $0.025
```

## 2. Read, in this order

| # | Document | Why |
| --- | --- | --- |
| 1 | `docs/PROCESS.md` | roles, packet contract, close log |
| 2 | the `CONTEXT.md` excerpt the session start injected (Current state, your queue entry BS-001) | live state; confirm BS-001 is still `open` or yours `in progress`. Do not read the rest of `CONTEXT.md` |
| 3 | `docs/00-context/GLOSSARY.md` | vocabulary used in every identifier |
| 4 | `docs/02-delivery/VERTICAL-SLICES.md` § S0 | the slice this packet implements |
| 5 | `docs/01-architecture/ARCHITECTURE.md` § 3 (process model), § 7 (layering rules), § 8 (disk layout), § 9 | structure you must keep |
| 6 | `schema/001_core.sql`, `schema/seed/apps.yaml`, `schema/seed/measures.yaml`, `schema/seed/rate_cards.example.yaml` | the DDL is the source of truth; seeds are loaded by `st init` |
| 7 | `docs/01-architecture/DATA-MODEL.md` § 2, § 3, § 6 | table dictionary, measure catalogue, migration policy |
| 8 | `docs/01-architecture/COST-MODEL.md` § 2 (`rate`, `list`), § 5 (nanos and micros) | the only pricing S0 does |
| 9 | `docs/01-architecture/ADAPTER-SPEC.md` § 6 | the envelope shape `st ingest` reads |
| 10 | `docs/01-architecture/WEB-UI.md` § 2 (Overview row), § 3 (`/health`, `/series`), § 5 | the one page and two endpoints |
| 11 | `docs/01-architecture/SECURITY-PRIVACY.md` | loopback binding, hostname hashing, no vendored network calls |
| 12 | `docs/00-context/adr/ADR-0001`, `ADR-0002`, `ADR-0006` | store, canonical event, stack |
| 13 | `docs/02-delivery/TESTING.md` | tiers, markers, blast radius, local commands |
| 14 | `docs/02-delivery/CI-CD.md` (product repo tables), `examples/ci/ci.yml`, `examples/ci/blast-radius.yaml`, `examples/ci/ci-issues.py` | what you install as `.github/workflows/ci.yml` |
| 15 | `docs/02-delivery/PHASE-PLAYBOOK.md` | commit prefix, `# CONTEXT:` comments, close checklist |

Not needed for this packet: `COLLECTORS.md`, `AGGREGATION.md`, `ADAPTER-SPEC.md` beyond § 6,
`ADR-0003/0004/0005/0008`, the research notes, `examples/` other than `examples/ci/`.

## 3. Acceptance criteria

The Fable session runs every one of these itself on your PR head. All must be MET.

| Id | Criterion |
| --- | --- |
| AC-1 | **Install.** `uv build` produces a wheel. `pipx install dist/*.whl` (or `uv tool install`) puts `st` on PATH. `st --help` lists `init`, `migrate`, `add`, `ingest`, `report`, `serve`, `doctor`, `adapter`, `version`. |
| AC-2 | **Init.** With `SPENDTRACKER_DB` unset and a fresh `HOME`, `st init --handle test-node --user-handle tester` creates `~/.spendtracker/spend.db` in WAL mode, applies `schema/001_core.sql`, leaves `schema_migration` at version 1, seeds every app in `apps.yaml` and every measure in `measures.yaml`, applies every rate card in `rate_cards.example.yaml`, and inserts exactly one `node` row (`node_id` a ULID, `hostname_hash` a sha256, never the hostname). A second `st init` changes nothing and exits 0. |
| AC-3 | **Migrate.** `st migrate` on an empty database applies 001. On the AC-2 database it reports nothing to apply and exits 0. On a database whose `schema_migration` version is higher than the binary's newest migration it exits 1 with a message naming both versions. |
| AC-4 | **Slice exit criterion.** After AC-2, `st add --app claude_api --measure token.output --qty 1000 --model claude-opus-5` exits 0, and `st report` prints exactly `$0.025` on stdout. |
| AC-5 | **Ingest.** `st ingest < envelopes.json`, where the file is a JSON array of two valid envelopes with distinct `source_ref`, inserts two `usage_event` rows, prices them, and prints `ingested 2, skipped 0, rejected 0`. Running the same command again prints `ingested 0, skipped 2, rejected 0` and the row count is unchanged. Newline-delimited objects on stdin are accepted the same way. |
| AC-6 | **Validation.** An envelope with an unregistered `measure`, an unregistered `app`, a negative or non-finite `quantity`, an `occurred_at` that is not ISO 8601 UTC ending in `Z`, or a `source` in {`hook`,`otlp`,`api`,`transcript`} with no `source_ref` is rejected: nothing from that envelope is inserted, the reason and the envelope index go to stderr, valid envelopes in the same batch are still inserted, and the exit code is 2. |
| AC-7 | **List pricing.** For each new event, the rate card is the most specific `sku_pattern` match (glob against `model`, then `sku`; `*` is least specific) among cards with the same `app_id` and `measure_id`, `tier = 'standard'`, latest `effective_from <= occurred_at`, and `effective_to` null or `> occurred_at`. `amount_micros = round_half_up(quantity × price_per_unit_nanos / 1000)`. The cost line has `cost_kind = 'list'`, `period_key = occurred_at[0:7]`, `pricer_version = '1'`. An event with no matching card gets no cost line, and `st report` prints `unpriced: N` on stderr when N > 0. |
| AC-8 | **Report.** `st report` prints the sum of `effective_micros` from `v_daily_cost` for the current UTC month as `$` followed by the amount with at most 6 decimals, trailing zeros trimmed, never fewer than 2 decimals: 25000 → `$0.025`, 1000000 → `$1.00`, 0 → `$0.00`. `--month YYYY-MM` selects another month. |
| AC-9 | **Serve.** `st serve` binds `127.0.0.1:8787` only. `GET /` returns 200 HTML that shows the same total as `st report` under the label "Effective this month" and a Chart.js daily series for the month. `GET /health` returns JSON with `status`, `schema_version`, `db_path`. `GET /api/v1/series?metric=effective&bucket=day&from=YYYY-MM-DD&to=YYYY-MM-DD` returns the daily series with money as `{"micros": n, "currency": "USD"}`. Chart.js and any CSS are vendored under the package; the page makes no request to any other host. |
| AC-10 | **Doctor.** `st doctor` prints the database path, schema version and node handle and exits 0 on a healthy install. When the database does not exist it prints a warning naming `st init` and still exits 0 (the CI `build` job runs it right after `pipx install`). It exits 1 only when the database exists but cannot be opened or its schema version is ahead of the binary. |
| AC-11 | **Local checks.** Every test carries exactly one of the markers `unit`, `integration`, `system`, registered with `--strict-markers`. Each of `uv run pytest -m unit`, `-m integration`, `-m system` collects at least one test and passes. `uv run ruff check .`, `uv run ruff format --check .` and `uv run mypy src` pass. |
| AC-12 | **CI.** `.github/workflows/ci.yml` is `examples/ci/ci.yml` with only the edits section 5 allows, and `.github/actions/ci-issues/action.yml` exists (the composite action `ci.yml` references; it wraps `examples/ci/ci-issues.py` as described in the comment at the bottom of `ci.yml`). On the PR, the checks `pr-author`, `blast-radius`, `lint`, `unit`, `integration`, `system`, `adapters`, `schema`, `docs` and `build` all succeed on the head commit. |
| AC-13 | **Schema snapshot.** `tests/schema_snapshots/head.sql` is the `.schema` output of a database built by applying `schema/*.sql` with the `sqlite3` CLI, generated by the tool, not typed by hand. The `schema` CI job compares the sorted files. |
| AC-14 | **Blast radius.** Every file under `src/spendtracker/` matches a rule in `examples/ci/blast-radius.yaml`. A change touching only package files produces no "unmapped paths" warning in the `blast-radius` job summary. |
| AC-15 | **Layering.** `core` and `pricer` import nothing from `cli`, `web` or `adapters`. `cli` calls `core`/`pricer`/`web` functions and holds no business logic. `web` reads SQL views and `core.api` only. |
| AC-16 | **Demo.** `README.md` gains a "Quick start" section with exactly the five commands: install, `st init`, `st add`, `st report`, `st serve`. The Status paragraph is updated to say S0 is built. |
| AC-17 | **Docs describe what was built.** Any deviation from the DDL, the envelope shape or the design is written into the relevant document in the same PR (PHASE-PLAYBOOK step 4) and listed under Deviations in the close log. |

## 4. Interfaces to honor

Names below are contracts. Later slices build on them; changing one needs a question first.

**Package layout** (`src` layout, hatchling build, `uv` project)

```
pyproject.toml            requires-python >=3.12 (ADR-0006); [project.scripts] st = "spendtracker.cli.main:app"
src/spendtracker/
  __init__.py             __version__ only
  core/                   db.py ids.py registry.py api.py ingest.py
  pricer/                 list_price.py
  cli/                    main.py (Typer app, thin)
  web/                    app.py templates/ static/ (vendored chart.js + its LICENSE)
  adapters/               __init__.py only (empty package; adapters arrive in S1)
  rollup/                 __init__.py only
tests/
  unit/ integration/ system/ pricer/ cli/ web/   (paths the blast-radius rules select)
  schema_snapshots/head.sql
```

Put every module under one of `core`, `pricer`, `cli`, `web`, `adapters`, `rollup`; a module at
the package root is unmapped in `blast-radius.yaml` and forces a full run with a warning.

**`core.db`**
- `db_path() -> Path`: `SPENDTRACKER_DB` if set, else `~/.spendtracker/spend.db`.
- `connect(path: Path) -> sqlite3.Connection`: creates the parent directory, sets
  `journal_mode = WAL` and `foreign_keys = ON`.
- `migrate(conn, sql_dir: Path) -> list[int]`: applies `NNN_*.sql` files whose version is not in
  `schema_migration`, in order, each in one transaction; returns the versions applied; raises
  `SchemaAhead(db_version, binary_version)` when the database is newer than the binary.
- The SQL and seed files ship **inside the wheel** and are read with `importlib.resources`.
  `schema/` at the repository root stays the single source; do not commit a second copy. Use the
  build backend's include or force-include mechanism to place `schema/**` in the wheel.

**`core.ids`**
- `ulid() -> str`: 26-character Crockford base32 ULID, time-ordered. Implement locally (about
  twenty lines); adding a ULID dependency would need an ADR.

**`core.registry`**
- `seed(conn, seed_dir: Path) -> None`: upserts `app` rows from `apps.yaml` and `measure` rows
  from `measures.yaml` (`is_cost` from the YAML, default 0). Idempotent.
- `apply_rate_cards(conn, path: Path) -> int`: upserts by `rate_id`. Conversion:
  `per_million` → `price_per_unit_nanos = round_half_up(price × 1000)`;
  `per_unit` → `round_half_up(price × 1_000_000_000)`. Integers only. Returns rows written.
- `ensure_node(conn, handle: str, user_handle: str) -> str`: inserts the node row if the table is
  empty and returns `node_id`. `hostname_hash = sha256(hostname)`.

**`core.api`**
- `UsageEvent` dataclass mirroring `usage_event` columns except `event_id`, `node_id`,
  `ingested_at`, `occurred_day`. `quantity: float` in the DTO is acceptable; money is never a float.
- `parse_envelopes(text: str) -> list[dict]`: accepts a JSON array or newline-delimited objects.
- Envelope fields accepted (ADAPTER-SPEC § 6): `v`, `adapter`, `app`, `occurred_at`, `measure`,
  `quantity`, `source`, `source_ref`, `model`, `sku`, `tool_name`, `mcp_server`, `actor`,
  `project_key`, `session_key`, `attrs`. In S0 `project_key` and `session_key` are stored inside
  `attrs` and not resolved (session and project resolution is S1).

**`core.ingest`**
- `ingest(conn, envelopes: list[dict], *, node_id: str) -> IngestResult`
  with `inserted: int`, `skipped: int`, `rejected: list[tuple[int, str]]` (envelope index, reason).
- Validation rules are AC-6. Duplicates are skipped by `INSERT OR IGNORE` against
  `ux_event_source`. `source = 'manual'` with `source_ref = NULL` always inserts.
- `adapter_id` is the envelope's `adapter` field, or `manual` for `st add`.

**`pricer.list_price`**
- `price_new_events(conn) -> int`: prices every event that has no `list` cost line, per AC-7;
  returns lines written. Idempotent. Called by `st add`, `st ingest` and `st serve` startup.
- `lookup_rate(conn, app_id, measure_id, model, sku, occurred_at) -> RateCard | None`.

**`cli.main`** (Typer)
- Commands: `init`, `migrate`, `add`, `ingest`, `report`, `serve`, `doctor`, `version`,
  `adapter test`. Exit codes: 0 success, 1 runtime error, 2 validation or usage error.
- `st init [--handle H] [--user-handle U]`: defaults are the OS user name for both.
- `st add --app A --measure M --qty Q [--model X] [--sku S] [--at ISO-UTC]`: builds one envelope
  with `source = manual`, `adapter = manual`, `source_ref = null`, `occurred_at` now unless `--at`.
- `st adapter test --all`: discovers `src/spendtracker/adapters/*/adapter.yaml`; with none found
  prints `no adapters found` and exits 0. The conformance suite itself is C-26 (S7); this stub
  exists only so the CI `adapters` job can pass on a full run.
- `st version [--all]`: package version; `--all` adds schema version.

**`web.app`**
- `create_app(db_path: Path) -> FastAPI`. Routes: `GET /`, `GET /health`, `GET /api/v1/series`.
  Jinja2 templates; htmx is optional in S0. Serve with uvicorn on `127.0.0.1:8787`; a `--host`
  other than loopback requires `--allow-remote` and prints a warning (SECURITY-PRIVACY.md).

**Conventions**
- Money is integer micros with a currency code, never a float. Rates are integer nanos.
- Timestamps are ISO 8601 UTC with a trailing `Z`. Days are `occurred_at[0:10]`.
- Commits: `S0/C-0n: <what>` (PHASE-PLAYBOOK). Add `# CONTEXT:` comments pointing at the ADR or
  section that explains a non-obvious choice.
- Dependencies allowed without asking (ADR-0006): `typer`, `fastapi`, `uvicorn`, `jinja2`,
  `pyyaml`; dev: `pytest`, `hypothesis`, `playwright`, `pytest-playwright`, `httpx`, `ruff`,
  `mypy`, `types-PyYAML`. Anything else: ask first.
- Python 3.12 is the target. Use `uv python install 3.12` if the machine has an older one; CI
  uses `setup-uv` and respects `.python-version`.

## 5. Files you may touch

| Allowed | Notes |
| --- | --- |
| `pyproject.toml`, `uv.lock`, `.python-version` | new |
| `src/spendtracker/**` | new |
| `tests/**` including `tests/schema_snapshots/head.sql` | new |
| `.github/workflows/ci.yml` | copy of `examples/ci/ci.yml`; the only permitted edit is making the composite action reference resolve. If a job cannot pass for a reason outside this packet (for example the `docs` link check finds a broken link in a design doc), do not delete or skip the job: record an issue with `issue.sh`, ask with `ask.sh`, and note it in the close log. |
| `.github/actions/ci-issues/action.yml` | new composite action per the comment at the bottom of `ci.yml` |
| `examples/ci/blast-radius.yaml` | add rules only if AC-14 needs them; do not change existing ones |
| `README.md` | "Quick start" section and the Status paragraph only |
| `CHANGELOG.md` | new; one line per capability delivered |
| `docs/01-architecture/*.md`, `docs/02-delivery/*.md` | only to record a deviation you had to make (AC-17), and say so in the close log |

Not allowed: `schema/*.sql` (a change needs a question and an ADR), `schema/seed/*` (fable
path), `docs/00-context/**` (ledgers; use the hook scripts), `.claude/**`, anything under
`examples/` other than the file above.

## 6. Build order with checkpoints

Each step ends green locally before the next begins. Push after every step so the draft PR and
CI reflect progress; a resumed session starts at the first unchecked step.

1. **Scaffold and CI.** `pyproject.toml` (hatchling, src layout, script `st`, ruff, mypy strict
   for `src/spendtracker/core` and `pricer`, pytest markers with `--strict-markers`),
   `.python-version`, `st version`, one trivial test in each tier so no tier collects zero tests
   (pytest exits 5 on an empty selection and the job goes red), `.github/workflows/ci.yml`, the
   `ci-issues` composite action. Push, open the draft PR. Checkpoint: `lint` green, tiers green,
   `blast-radius` summary shows a full run (pyproject and workflows are full-run paths).
2. **Store.** `core.db`, `core.ids`, `st migrate`, `tests/schema_snapshots/head.sql`. Tests:
   unit migrate on empty DB; integration migrate twice and refuse a newer DB (AC-3). Checkpoint:
   `schema` job green.
3. **Registry and init.** `core.registry`, `st init`, `st doctor`. Tests: unit seed counts equal
   the YAML counts; unit rate card conversion (per_million 25.00 → 25000 nanos; per_unit 0.006 →
   6_000_000 nanos); integration `st init` twice (AC-2). Checkpoint: `build` job green
   (`pipx install` then `st doctor`).
4. **Ingest.** `core.api`, `core.ingest`, `st ingest`, `st add`. Tests: unit validator per AC-6
   rule; integration idempotency (AC-5); a `hypothesis` property test that any valid envelope
   round-trips once and only once is welcome but optional. Checkpoint: `integration` green.
5. **Pricer and report.** `pricer.list_price`, `st report`. Tests: unit rate lookup precedence
   (specific pattern beats `*`; later `effective_from` beats earlier; `effective_to` excludes),
   unit rounding half-up at the micro boundary, system `tests/system/test_cli_smoke.py`
   (init → add → report prints `$0.025`, AC-4, AC-8). Checkpoint: `system` green.
6. **Web.** `web.app`, Overview template, vendored Chart.js, `/health`, `/api/v1/series`,
   `st serve`. Tests: unit API contract with `httpx` TestClient; system
   `tests/system/test_overview.py` Playwright smoke that the page shows the report total.
   Checkpoint: `system` green with Playwright.
7. **Finish.** README Quick start, CHANGELOG, `# CONTEXT:` comments, AC-17 doc deltas, run the
   full local check list (AC-11), then `/close-out`.

## 7. Out of scope

Collectors and adapters of any kind (S1), hooks, OTLP receiver, spool and watcher, session or
project resolution, `config.toml`, subscriptions and allocation, reported cost, budgets, FX,
export and rollup, any page beyond Overview, htmx partials, the scheduler, compaction, the release
workflow, nightly CT and the rollup workflow (BS-002), the adapter conformance suite (S7),
publishing to a package index. Do not build ahead even when it looks cheap.

## 8. Tests required

| Path | Tier | Proves |
| --- | --- | --- |
| `tests/unit/test_migrate.py` | unit | 001 applies on an empty DB; `schema_migration` has version 1 |
| `tests/integration/test_migrate_twice.py` | integration | second run applies nothing; newer DB refused with exit 1 |
| `tests/unit/test_registry.py` | unit | seed counts match YAML; rate conversions; node row shape |
| `tests/integration/test_init.py` | integration | AC-2, including idempotent second run and WAL mode |
| `tests/unit/test_validator.py` | unit | one test per AC-6 rule, plus the manual-without-source_ref success case |
| `tests/integration/test_ingest_idempotent.py` | integration | AC-5, array and newline-delimited input |
| `tests/pricer/test_lookup.py` | unit | AC-7 precedence and date rules; no-rate → no line |
| `tests/pricer/test_rounding.py` | unit | half-up at the micro boundary; 1000 × 25000 nanos → 25000 micros |
| `tests/cli/test_report_format.py` | unit | AC-8 formatting table |
| `tests/system/test_cli_smoke.py` | system | init → add → report prints `$0.025` in a temp HOME |
| `tests/web/test_api.py` | unit | `/health` shape; `/api/v1/series` money shape and day buckets |
| `tests/system/test_overview.py` | system | Playwright: page shows "Effective this month" and the same total as `st report` |

Every test uses a temporary directory for `HOME` or `SPENDTRACKER_DB`; no test touches the real
`~/.spendtracker`. No test needs the network.

## 9. Known constraints

- 40 prompts per session (`SESSION-PROTOCOL.md`). The checkpoints in section 6 are the resume
  points; do not skip the pushes between them.
- The container used by cloud sessions has Chromium pre-installed for Playwright
  (`PLAYWRIGHT_BROWSERS_PATH`); do not run `playwright install` locally there. CI installs it.
- `PR_AUTHOR_LOGIN` is set on the repository; PRs opened through the GitHub MCP tools pass the
  `pr-author` job. Create the PR as a draft.
- No secrets, tokens, emails or hostnames in fixtures or tests (TESTING.md hygiene).
- Do not edit `.claude/hooks/**`, the ledgers, or `CONTEXT.md`; the hooks deny it and the Fable
  session folds your log entries in.

## 10. Close log

Run `/close-out`. In addition to what the skill lists, the PR body and the `log.sh close` entry
must contain:

- an AC table: every AC-n with MET, NOT MET or UNVERIFIED and the evidence (command and output,
  or the CI check name);
- Deviations: anything built differently from this packet or the design, and where you wrote it
  into the docs;
- Assumptions: each one and what changes if it is wrong;
- Spend: model, input and output tokens, wall-clock minutes, tool calls, sessions used. This
  project's subject matter; never omitted.

## 11. Fable's standing items for this entry

- Fix issues: none assigned.
- Act on answers: none yet.
- Changes requested by Fable: none yet.

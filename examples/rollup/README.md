# Example rollup repository layout

This directory mirrors what a team's `spend-rollup` repository contains. See
`docs/01-architecture/AGGREGATION.md`.

- `data/<node>/<YYYY>/<YYYY-MM>.jsonl` — append-only export batches (sample lines included)
- `data/<node>/<YYYY>/<YYYY-MM>.manifest.json` — counts and hash
- `team/*.yaml` — canonical rate cards, subscriptions, budgets, nodes
- `schema/export-v1.schema.json` — validated by CI on every PR
- `.github/workflows/rollup.yml` — copy from `examples/ci/rollup.yml`

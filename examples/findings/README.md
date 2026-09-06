# Golden findings fixtures

One JSONL file per rule pack and case: `<pack>-<case>.jsonl`. Each line is either a `finding` or a
`proposal` in the shape `st findings run` produces (FINDINGS.md §2, `schema/002_findings.sql`).
`st findings test <pack>` replays the pack's fixtures against a store loaded from the matching
`examples/adapters/<pack>/fixtures/` and diffs the result. Signatures are computed at replay time
from the stated fields, so fixtures carry the discriminator, not the hash.

| File | Source | What it proves |
| --- | --- | --- |
| `github-actions-2026-09.jsonl` | `docs/00-context/research/S3-github-actions-run-usage.md` | The GitHub Actions rule pack reproduces the seven proposals of the 2026-09-06 analysis with their measured minutes and extrapolated savings |

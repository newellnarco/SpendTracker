# ADR-0008: CI runs tiered tests by blast radius and feeds a known-issues ledger

**Status:** Accepted — 2026-09-03

## Context

Builder sessions are short and numerous. A full CI run on every push is slow and its failures
evaporate into job logs, so the same defect gets rediscovered by the next session. The owner wants
CI to cover unit, integration and system testing scoped to what a change can affect, a full run only
when required, and every CI-found issue kept in a ledger that the Fable session keeps current and
that builders read before they start.

## Decision

- Tests are tagged by tier (`unit`, `integration`, `system`) and each tier is a separately named
  check. Lint, schema, docs and build remain their own jobs.
- A `blast-radius.yaml` map from path globs to tiers and test selectors drives selection. A
  `blast-radius` job computes the selection from the PR diff and records it in the job summary. Full
  runs are forced for `ci_full_run_paths` (schema, core, workflows, dependency manifests), pushes to
  `main`, the `full-ci` label or `[full-ci]` commit trailer, and nightly CT.
- Failing jobs emit `ci-issues.jsonl` (check, test id, signature, message, paths) as an artifact
  and one PR comment. `docs/00-context/KNOWN-ISSUES.md` is the ledger; `issue.sh` appends entries
  with a signature for de-duplication; the Fable session assigns, marks fixed, and refuses to merge
  a PR whose CI failures are not in the ledger.
- The SessionStart hook injects open issues with their blast radius into every session.

## Consequences

- Typical builder pushes run in minutes; full runs still protect `main` and the nightly.
- The map must be maintained: a new package without a `blast-radius.yaml` entry falls into the
  default rule that runs the full matrix, which is safe but slow, and a warning in the summary
  says so.
- The ledger grows; `fixed` entries older than 90 days are folded into a summary section by the
  Fable session.

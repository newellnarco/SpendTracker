# GitHub Actions run-level usage: where 3,000 minutes went in five days

Date: 2026-09-06  Author: builder session `8a142028` (owner task)
Verified against: GitHub REST `GET /repos/{owner}/{repo}/actions/runs` (with `created=>=YYYY-MM-DD`),
`GET /repos/{owner}/{repo}/actions/runs/{id}/jobs?filter=all`, `GET /repos/{owner}/{repo}/actions/runs/{id}/timing`,
the workflow files on `main` of each repository, and the owner's billing page screenshot
("Usage by repository, top five repositories this month") taken 2026-09-06.

## Phase brief

- Goal: explain why the account's 3,000 included Actions minutes were consumed between 2026-09-01
  and 2026-09-06, attribute the minutes to repositories, workflows, jobs and triggers, and turn the
  causes into proposals with an estimated monthly saving.
- In scope: every repository the session could attach (`SpendTracker`, `netsniff`, `MAX3`,
  `Maxresearchcollective`, `black-and-white`, `Hal2000`, `AppPlexMovies`).
- Out of scope: repositories the GitHub App is not installed on; account-level billing endpoints
  (blocked for this session, see Surprises).
- Exit: the numbers reconcile with the billing page per repository; each cause has a proposal.

## Findings

### Method

1. List runs per repository since the first of the month, all pages.
2. For every run that is not `skipped`, list its jobs. A job's paid time is
   `completed_at − started_at` when the runner label is GitHub-hosted; a self-hosted runner label
   (`SCOUT_RUNNER` → `max3-box`) is free.
3. Group by repository, workflow, job, event, branch, day. Price at $0.008 per Linux minute.
4. Compare with the billing page.

### Reconciliation with the billing page

| Repository | Paid minutes (measured) | At $0.008/min | Billing page |
| --- | ---: | ---: | ---: |
| Maxresearchcollective | 1,330 | $10.64 | $9.41 |
| MAX3 | 1,131 | $9.05 | $9.17 |
| netsniff | 73 | $0.59 | $0.68 |
| SpendTracker | 13 | $0.10 | $0.08 |
| All other repositories | not visible | | $12.07 |

Measured totals track the billing page per repository within rounding and reporting lag.
The three older private repositories have zero runs this month, so the "All other repositories"
line is spend the installed GitHub App cannot see (a repository it is not installed on, a deleted
repository, or a non-Actions product on the same panel).

### Attribution, Maxresearchcollective (1,330 min)

| Job | Minutes | Cause |
| --- | ---: | --- |
| `Checks :: mutation-changed` | 452 | Runs on every push to a PR; averages 15 min although its own comment says the scoped run should take seconds. Two PR branches spent 439 and 286 min here |
| `Deploy site to IONOS :: gate-mutation-1..4` | 300 | Full mutation suite re-run on every merge to main, right after the PR and the push-to-main Checks passed on the same tree |
| `Deploy site to IONOS :: deploy` | 184 | One `curl` process per file over SFTP; 19 to 33 min per deploy, ten deploys in five days |
| `pr-review.yml :: Gemini review` | 205 | ~5 min per push (`fetch-depth: 0` + pip install); 48 runs for three PRs |
| `Checks :: deep` | 102 | Every PR push |
| Scheduled jobs (`refresh-feedback` 2-hourly, `fleet-sync` 6-hourly, digests) | 19 | Seconds each; not a problem |

### Attribution, MAX3 (1,131 min)

| Cause | Minutes | Detail |
| --- | ---: | --- |
| Full CI pyramid on PR pushes | 699 | Four backend shards of 8 to 14 min plus security and frontend, ~45 min per push; 14 runs across three PRs on 2026-09-05 |
| `CI webhook fallback` dispatching full CI on PR #1596 | 337 | Every push to draft branch `claude/new-session-neniem` produced zero `pull_request` check runs, so the 20-minute sweep dispatched a full pyramid eight times in three days, including four docs-only paper commits |
| Runs cancelled by a newer push mid-run | 288 (all repos) | Four `fix/ollama-keepalive` runs on 2026-09-05 burned 72 min before cancellation |
| Sep 4 huggingface PR run | 87 | The CUDA torch ENOSPC failure recorded in `ci.yml` as F-CI-022 |
| Gemini review, Copilot review, project-md-bundle | 68 | Expected |
| Webhook sweeps and telemetry alarm themselves | 33 | 350 runs, seconds each |

SCOUT runs on the self-hosted box: 88 min of wall time, $0. Claude review is paused in both
repositories: $0.

### Rate of spend

2,547 paid minutes in five days across the four visible repositories; at that pace the month lands
near 15,000 minutes against the 3,000 included.

## Surprises (things that contradict current docs)

1. **Billing is per second, not rounded up per job.** Summing raw job seconds matched the billing
   page; rounding each job up to a whole minute overstated every repository by ~35 %. The 350 short
   scheduled runs in MAX3 cost 33 min, not 350. COLLECTORS.md §4 says minutes are stored as
   `minutes × 60`; the run-level adapter stores seconds directly.
2. **`GET .../actions/runs/{id}/timing` returns `billable.total_ms = 0` for every run**, hosted or
   not. It cannot be used for cost. Job `started_at`/`completed_at` plus runner labels are the
   usable signal.
3. **Copilot code review runs (`dynamic/agents/copilot-pull-request-reviewer`) are billed as Actions
   minutes**, even on the public `SpendTracker` repository (13 min, $0.08 on the billing page).
4. **Account-level billing endpoints are not reachable from a Claude Code session**: the session
   proxy answers `403 This GitHub API path is not available: sessions are bound to their
   configured repositories`. The billing adapter designed in COLLECTORS.md §4 must run on the user's
   machine with the user's token, never inside a session.
5. **Self-hosted runner jobs appear in the same job list** with their runner label and
   `runner_group_name`; they must be priced at zero.
6. **`skipped` conclusions dominate run counts** (Claude review posted 132 skipped runs in MAX3 at
   $0); run counts are not a proxy for cost.

## Proposals derived from the findings (ranked by minutes saved per month)

| # | Repository | Proposal | Est. saving / month |
| --- | --- | --- | ---: |
| 1 | MAX3 | Stop the sweep from re-dispatching full CI on PR #1596: close or rebase the draft, make the sweep skip draft heads older than N days, or dispatch with a docs-only classification. Find out why that branch's pushes fire no `pull_request` events | ~2,000 min |
| 2 | Maxresearchcollective | Take `mutation-changed` off the per-push PR loop: run once on `ready_for_review`, on a label, or only in the weekly sweep and the deploy gate. Measure the selector before trusting it again | ~2,700 min |
| 3 | Maxresearchcollective | Do not re-run the four full mutation shards on every deploy; skip the gate when Checks passed on the identical tree SHA (MAX3's tree-SHA skip) | ~1,800 min |
| 4 | Maxresearchcollective | Replace the per-file curl upload with one `lftp mirror --reverse --parallel` or a tar push plus remote extract; skip the deploy when the merge touched nothing under the shipped payload | ~1,100 min |
| 5 | all | Stop pushing to PRs in rapid bursts, or widen concurrency cancellation to the whole PR; batch commits locally and push once per review round | ~1,700 min |
| 6 | Maxresearchcollective | Gemini review only on `opened` and `ready_for_review`; drop `fetch-depth: 0`; cache pip | ~1,200 min |
| 7 | MAX3 | Run shard-scoped unit tiers on `synchronize` and the full four-shard pyramid on `ready_for_review` | ~3,000 min at the 2026-09-05 rate |

Estimates extrapolate the five measured days to thirty; they overlap (5 and 7 share runs), so the
sum is not additive.

## What this changes

- docs updated: `01-architecture/COLLECTORS.md` (§4b GitHub Actions runs adapter),
  `01-architecture/FINDINGS.md` (new), `01-architecture/DATA-MODEL.md` (§7 findings tables,
  measure catalogue rows), `01-architecture/ARCHITECTURE.md` (findings engine in D-CONT and D-COMP,
  layering rule 6), `01-architecture/WEB-UI.md` (Findings page and API), `00-context/GLOSSARY.md`,
  `02-delivery/CAPABILITIES.md` (C-31, C-32, C-33), `02-delivery/VERTICAL-SLICES.md` (S3b),
  `docs/README.md`.
- schema added: `schema/002_findings.sql` (designed, not applied).
- fixture added: `examples/findings/github-actions-2026-09.jsonl` (the findings and proposals above
  in the canonical shape; the golden case for the GitHub Actions rule pack).
- ADR needed: yes, ADR-0011 (findings and proposals are derived, recomputable rows produced by rule
  packs that adapters ship).
- CONTEXT.md (Fable session): add this note to the research table, ADR-0011 to the decisions log,
  and a builder session queue entry for S3b (proposed text in the PR description).
- Open question for the owner: which repositories should the `github_actions_runs` adapter be
  pointed at, and does the "All other repositories" line resolve to a repository once the billing
  page is filtered to Actions? (Extends Q-2.)

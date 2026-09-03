# Session protocol: roles by model, prompt limits, ledgers, CI and merges

Two kinds of Claude Code sessions work on this repository. The role is decided by the model the
session starts with and is enforced by the hooks in `.claude/hooks/` (registered in
`.claude/settings.json`, tunable in `.claude/hooks/policy.json`).

## Hard rules

1. **Every pull request is opened under the owner's GitHub username** (`pr_author_login` in
   `policy.json`, currently `newellnarco`). Never by a bot, app or other account. The `pre-tool`
   hook checks `gh` identity when it can, and the CI `pr-author` job rejects any other author. A PR
   from another identity is closed, not merged.
2. **Only the Fable session answers questions, curates the ledgers, verifies CI and merges.**
3. **Builder sessions build one queue entry on their own branch and PR, then stop.** They read all
   context and design first, take the next open entry of the builder session queue in `CONTEXT.md`
   (or resume their own in-progress one), fix the issues and apply the answers and changes Fable
   listed there, ask, report progress, record issues, and never merge or touch `main`.
4. **No session runs past 40 prompts.** Every session ends with a close-out that leaves its
   questions, issues and progress in the repository.
5. **Every known issue is in the ledger before anyone moves on.** A CI failure or an observed
   defect that is not in `KNOWN-ISSUES.md` is a protocol violation for the session that saw it.
6. **CI runs the tiers and the blast radius the change needs, not everything every time.** A full
   run is required only for core, schema or workflow changes, on `main`, or when the Fable session
   asks for one.

## Roles

| | Fable session | Builder session (Opus, Sonnet, others) |
| --- | --- | --- |
| Model | matches `fable\|mythos` | anything else |
| Purpose | Read the ledgers, answer questions, curate known issues from CI output, review progress, verify CI tiers and blast radius, merge, write the builder session queue and the rest of `CONTEXT.md`, check in | Read all context and design, pick up the next open (or its own in-progress) entry in the builder session queue, do it end to end on its own branch and PR, acting on the issues, answers and changes Fable listed, then stop |
| May edit | `docs/`, `.claude/`, `README.md`, `CHANGELOG.md`, `schema/seed/` | anything except the ledger files |
| Ledger writes | answers (`answer.sh`), issue curation, `CONTEXT.md`, log entries | questions (`ask.sh`), issues (`issue.sh`), log entries (`log.sh`) |
| Merge / push to main | yes | no |
| Switch model mid-session | no | no |
| Prompt limit | 40 | 40 |
| Ends with | `log.sh close` after `/fable-review` | `/close-out` |

## Interaction (D-SESSION)

```mermaid
sequenceDiagram
    participant B as Builder session (Opus)
    participant R as Repo (work branch + draft PR)
    participant CI as CI (unit · integration · system, blast radius)
    participant L as Ledgers (QUESTIONS · KNOWN-ISSUES · SESSION-LOG)
    participant F as Fable session
    participant M as main

    Note over B: SessionStart injects role, CONTEXT.md (state + builder session queue), open issues, answered and pending questions
    B->>R: take next open BS entry; branch work/<slice>-<topic>, commits, draft PR by owner username
    R->>CI: run tiers selected by blast radius
    CI-->>R: check runs + ci-issues artifact + PR comment
    B->>L: ask.sh (questions) · issue.sh (failures seen) · log.sh progress
    Note over B: prompt 35 warning · prompt 40 forced close-out · 41+ blocked
    B->>L: log.sh close
    B-->>B: stop
    Note over F: SessionStart scans every branch for pending questions and open issues
    F->>L: answer.sh per question · issue.sh / edit to curate issues
    F->>R: read diff, author, check runs, blast-radius summary
    alt author ok, green, mergeable, answered, issues recorded
        F->>M: merge PR
    else anything missing
        F->>L: log why and the next action for a builder
    end
    F->>M: update CONTEXT.md (queue: next entries, issues to fix, answers, requested changes), commit, push
    F->>L: log.sh close
```

## Ledger files (all in `docs/00-context/`)

| File | Written by | Entry shape |
| --- | --- | --- |
| `QUESTIONS.md` | builders via `ask.sh`; Fable via `answer.sh` | `Q-YYYYMMDD-xxxx`, Status pending/answered/needs-human, Asked, Question, Context, Answer (Fable), Answered |
| `KNOWN-ISSUES.md` | any session via `issue.sh`; Fable curates status and assignment | `I-YYYYMMDD-xxxx`, Status open/fixed/wontfix, Title, Signature (hash of check+title, used for de-duplication), Check tier, Blast radius paths, Detail, Ref, Recorded, Assigned |
| `SESSION-LOG.md` | any session via `log.sh` | `start / progress / close` with session id, model, role, branch, prompt count; `auto` when written by the SessionEnd hook |
| `CONTEXT.md` | Fable only | current state, owner/Fable next actions, builder session queue (`BS-nnn` entries: slice, branch, goal, read list, scope, exit criteria, issues to fix, answers to act on, changes requested by Fable; status open/in progress/blocked/done), decisions, open questions, phase history |

Random id suffixes mean two branches never collide. Entries are append-only; concurrent edits merge
by keeping both sides.

Builder questions and issues are committed on the builder's branch. The Fable start hook fetches
origin and scans every branch's `QUESTIONS.md` for pending entries, so nothing waits on a merge to
be seen. Fable answers on the branch that holds the question (checking it out) or on main with a
note; when the PR merges, the ledgers merge with it.

## CI: tiers, blast radius, issue output

- **Tiers** are separate named checks: `unit`, `integration`, `system` (plus lint, schema, docs,
  build). The Fable review requires all three present and green on the head commit.
- **Blast radius**: `examples/ci/blast-radius.yaml` maps path globs to the test selectors and tiers
  they affect. The `blast-radius` job diffs the PR against its base, computes the selection, and
  writes a job summary listing tiers run and paths covered. A change touching any
  `ci_full_run_paths` entry (schema, core, workflows, dependency manifests), a push to `main`, the
  label `full-ci`, or `[full-ci]` in a commit message forces the full matrix. Nightly CT always runs
  everything.
- **Issue output**: every failing job converts its JUnit report into `ci-issues.jsonl` (one line
  per failure: check, test id, signature, message, paths) with `examples/ci/ci-issues.py`, uploads
  it as an artifact and posts one PR comment listing signatures. The builder records each new
  signature with `issue.sh`; the Fable review verifies the ledger matches the artifact before
  merging.
- **Known issues at session start**: the start hook injects open entries with their blast radius so
  builders avoid reintroducing them and only fix the ones assigned to their task.

## Enforcement map

| Rule | Hook | Mechanism |
| --- | --- | --- |
| Role from starting model | `SessionStart` → `session-start.sh` | `model` field, stored in `.claude/state/sessions/<id>.json` (gitignored) |
| Context on start | same | `additionalContext` with role brief, `CONTEXT.md` current state, open known issues, pending questions on this and other branches, open branches/PRs, last log entries |
| 40-prompt limit | `UserPromptSubmit` → `prompt-submit.sh` | counter per session; warning at 35, forced close-out instruction at 40, prompts blocked (exit 2) at 41+ or after close-out |
| Close-out before ending at the limit | `Stop` → `stop.sh` | blocks the stop (exit 2) with instructions when prompts ≥ 40 and no close entry |
| Unfinished sessions are visible | `SessionEnd` → `session-end.sh` | appends an `auto` close entry when no close-out was logged |
| Builders cannot merge or touch main | `PreToolUse` → `pre-tool.sh` | denies `git merge`, `gh pr merge`, pushes to protected branches or force pushes, `git checkout main`, GitHub MCP merge/auto-merge tools, MCP file writes to main |
| Builders cannot answer or edit ledgers directly | same | denies Edit/Write to the ledger files and shell writes to them; denies `answer.sh` |
| Fable does not build | same | denies Edit/Write outside the Fable-editable paths |
| PR author is the owner | same + CI `pr-author` job | `gh api user` check when `gh` exists; reminder on the MCP tool; CI fails any other author |
| Roles cannot be swapped by switching model | `PreModelSwitch` → `pre-model-switch.sh` | blocks the switch |

## What the hooks cannot enforce

- Anything done outside Claude Code (the GitHub web UI, a plain terminal). Branch protection on
  `main` (required checks, no direct pushes, PR author restriction via CODEOWNERS or rulesets) is
  the backstop; enable it.
- Prompt counting is per session id. `/clear` starts a new id and a new count; a session that
  clears to dodge the limit is visible in the log as an `auto` close entry without a real close-out.
- Sessions started before the hooks existed have no recorded model and are treated as builders.
  Set `SPENDTRACKER_ROLE=fable` in the Claude Code process environment to override for one
  session. Hooks also apply to the session that authored them; this design session was classed as
  a builder and could not edit `CONTEXT.md`, which is why that update is listed as a next action.
- The Fable "no building" rule is a path allowlist over Edit/Write; it does not stop shell commands
  that write code. It is a guardrail, not a sandbox.
- The `pre-tool` PR-author check needs `gh`; the MCP path is enforced by CI only.
- CI verification depends on CI existing. Until slice S0 lands `ci.yml`, the Fable checklist says
  to treat PRs as not mergeable unless the user overrides.

## Operating notes

- The hooks need `jq`, `git` and `python3` (for `answer.sh`). `gh` is optional.
- All state lives in `.claude/state/` and is gitignored.
- Change limits, protected branches, editable paths, the PR author and full-run paths in
  `.claude/hooks/policy.json`.
- The skills `/close-out` and `/fable-review` in `.claude/skills/` are the two role checklists.

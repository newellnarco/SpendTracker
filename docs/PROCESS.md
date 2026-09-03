# SpendTracker development process: division of labor

This document defines who does what across the two kinds of Claude Code sessions that work on
this repository, and the contracts that connect them: the task packet, the question protocol, the
close log, and Fable's verification.

**Precedence.** The mechanics (roles by model, hooks, ledger files, prompt limit, PR author rule,
CI tiers) are decided in ADR-0007 and ADR-0008 and specified in
`docs/02-delivery/SESSION-PROTOCOL.md`; the hooks in `.claude/hooks/` enforce them. This document
adds the division of labor and the packet contract on top. Where the two disagree,
SESSION-PROTOCOL.md wins until an ADR changes it (section 15).

## 1. Roles

| | Fable session (lead) | Builder session (developer) |
| --- | --- | --- |
| Model | matches `fable\|mythos` (`policy.json`) | anything else |
| Is | architect, project manager, designer, product owner's delegate | developer and tester for one packet |
| Context | full: design, ADRs, phases, all ledgers, all builder close logs | `docs/PROCESS.md`, its packet, the documents the packet lists, plus what CONTEXT.md and the hooks inject at start (see Q-6 in CONTEXT.md on how wide this should be) |
| Writes code | never | yes, inside the packet's file list |
| Writes tests | acceptance criteria in the packet; may add acceptance fixtures under `schema/seed/` | unit, integration and system tests for its own code |
| Runs CI and verification | yes, independently, on every PR head | locally before every push |
| Reviews | code and architecture; issues action items to the builder through the queue entry | may review any PR and comment |
| Marks a PR ready | yes | yes; any session may |
| Merges | yes, when green, author-compliant, questions answered, issues recorded | never (hook-denied) |
| May edit | `docs/`, `.claude/`, `README.md`, `CHANGELOG.md`, `schema/seed/` (`fable_editable_paths`) | anything except the ledger files |
| Ledger writes | answers (`answer.sh`), issue curation, `CONTEXT.md`, log entries | questions (`ask.sh`), issues (`issue.sh`), log entries (`log.sh`) |
| Ends with | `/fable-review` checklist, `log.sh close` | `/close-out` |

### 1.1 Role is recorded, never assumed

The SessionStart hook derives the role from the model and stores it in `.claude/state/`. A
session cannot see its own model reliably, and a session that started before the hooks were
checked out has no record and is treated as a builder. In that case the documented override is
`SPENDTRACKER_ROLE=fable` in the process environment; when the environment cannot be set, the
session verifies its model with the session tooling (for cloud sessions, `get_session`), corrects
its state file, and says so in its first `log.sh` entry. A builder never reclassifies itself.

## 2. Where things live

| Concept in this document | Where it is in this repository |
| --- | --- |
| Task packet | a builder session queue entry `BS-nnn` in `docs/00-context/CONTEXT.md`, expanded into `docs/tasks/BS-nnn-<slug>.md` |
| Phase and task status | `CONTEXT.md` (Current state, Builder session queue, Phase history). Fable writes only. |
| Decisions | `CONTEXT.md` decisions log, backed by an ADR in `docs/00-context/adr/` for anything architectural |
| Builder questions and Fable answers | `docs/00-context/QUESTIONS.md` via `ask.sh` and `answer.sh` |
| Defects and CI failures | `docs/00-context/KNOWN-ISSUES.md` via `issue.sh`; Fable curates |
| Session logs, including close logs | `docs/00-context/SESSION-LOG.md` via `log.sh`; the close-out summary is also the PR body |
| Design | `docs/01-architecture/`, `docs/02-delivery/`, `schema/` |

Every session writes only through the paths and scripts its role allows. Entries are append-only.

## 3. The task packet

Fable writes one packet per builder session. A builder starts with no memory of anything, so the
packet must stand alone with the documents it lists. Sections, in order:

```
# BS-nnn · <short name>
ROLE / AUTHOR · SPEC-COMMIT (the main commit the packet was cut from) · PHASE / SLICE · BRANCH ·
CAPABILITIES · STATUS
0. How to use this packet      the builder's operating instructions
1. Goal                        one paragraph: what exists when this is done
2. Read, in this order         the only documents the builder needs, and why each
3. Acceptance criteria         numbered AC-n, each testable; Fable runs them all
4. Interfaces to honor         names, signatures, shapes, conventions later work builds on
5. Files you may touch         explicit list; anything else is out of scope
6. Build order with checkpoints ordered steps, each ending green, each a resume point
7. Out of scope                what not to build even when cheap
8. Tests required              path, tier, what it proves
9. Known constraints           limits, environment, hygiene
10. Close log                  what the builder must report beyond /close-out
11. Fable's standing items     Fix issues · Act on answers · Changes requested by Fable
```

Packets in flight at the same time have disjoint "Files you may touch" lists
(`CAPABILITIES.md`, ownership of state). Fable enforces this.

A packet is sized to one session (40 prompts). When a packet is too large, the checkpoints in
section 6 make it resumable: the queue entry is marked `in progress` with the branch and PR, and
the next builder session continues from the first unmet checkpoint.

## 4. Builder session rules

The full list is `SESSION-PROTOCOL.md` and the builder brief injected at session start. The
rules this document adds:

1. Read this file and the packet. Then read the packet's list, in order. Do not start from the
   code.
2. Build to the acceptance criteria. Do not widen scope, do not refactor outside the allowed
   files, do not build ahead into a later slice.
3. Write tests for every new code path, in the tier the packet names. Run lint, format, type
   check and all three tiers before every push.
4. Never modify, skip or quarantine an existing test to get green. Record the failure with
   `issue.sh` instead.
5. Push at every checkpoint. The draft PR is the record of progress.
6. Reviewing and marking a PR ready is allowed. Merging is not.

## 5. Question protocol

- Ask with `ask.sh`, one question per call, with `--context` saying what depends on the answer
  and the assumption you will proceed under if no answer arrives.
- If the answer blocks the packet: `log.sh progress` why, `/close-out`, stop. The queue entry
  becomes `blocked`.
- If it does not block: record the assumption with `log.sh progress`, continue, and list the
  assumption in the close log.
- Only Fable answers (`answer.sh`). An answer is an instruction; the builder acts on it. Fable
  marks a question `needs-human` when only the owner can decide, and mirrors it into the
  CONTEXT.md open-questions table.

## 6. Close log

`/close-out` produces the log entry, the questions, the issues, the push and the draft PR. On top
of that the PR body and the close entry carry:

- the acceptance criteria table: every AC-n with MET, NOT MET or UNVERIFIED and evidence;
- Deviations from the packet or the design, and where in the docs they were recorded;
- Assumptions made and what changes if each is wrong;
- Spend: model, input and output tokens, wall-clock minutes, tool calls, sessions used.

Fable treats the close log as a report to verify, not as truth.

## 7. Fable review and verification

On each builder close-out, following `/fable-review`:

1. Check out the PR head and run lint, type check and all three tiers itself. The close log's
   pasted output is not a substitute.
2. Run every acceptance criterion in the packet.
3. Read the diff against "Files you may touch". Anything outside it is a finding.
4. Read the diff for correctness and architectural fit, not only for green checks.
5. Confirm CI covered the change's blast radius on the head commit, the PR author is the owner's
   username, every question on the branch is answered, and every CI failure is in the ledger.
6. Record the outcome in its session log and in `CONTEXT.md`.

Outcomes:

- **Accept.** Merge per section 8. Mark the entry `done` with the merged commit.
- **Rework.** Write the findings as numbered items under the entry's "Changes requested by
  Fable", "Fix issues" (with issue ids) and "Act on answers" (with question ids). Same branch,
  same scope. The next builder session takes the entry. Repeat until accept.
- **Redesign.** The flaw is in the design, not the build. Fable updates the architecture docs,
  writes or supersedes an ADR, records the decision, and reissues the packet with a new
  `SPEC-COMMIT`.

Fable advises and directs; it never makes the code change itself.

## 8. Branch, merge and rollback

- One packet per branch, named as the packet says (`work/<slice>-<topic>`).
- Builders push only to their branch. Every PR is a draft under the owner's username.
- Fable merges accepted PRs. While the repository has no CI workflow, PRs are not mergeable
  unless the owner overrides, and the override is logged.
- No history rewriting on a branch a builder has pushed to: no rebase, amend or force-push.
- A merged packet that breaks `main` is reverted by Fable at once and reissued as a rework
  entry. Fable does not patch forward.

## 9. What Fable may and may not edit

Fable edits only `fable_editable_paths` in `policy.json`: `docs/`, `.claude/`, `README.md`,
`CHANGELOG.md`, `schema/seed/`. Application code, tests, CI workflows and `schema/*.sql` go
through a packet to a builder. The one exception is the revert in section 8.

## 10. Human decision rights

Fable stops and asks the owner for:

- closing a phase or slice and opening the next;
- any change to architecture, interfaces or scope that needs a new or superseded ADR;
- adding a dependency outside ADR-0006, or an external service;
- anything that changes the cost profile of the project;
- a builder disagreement with a packet that the design does not settle;
- applying branch protection or repository settings (cannot be done from a session);
- changing this document or SESSION-PROTOCOL.md.

Everything else Fable decides and records in the decisions log.

## 11. Status source of truth

`CONTEXT.md` is the only place phase and task state lives. Builders report through their logs
and never touch it. The Fable session updates it as the last step of every phase and whenever a
decision is made.

## 12. Spend

Every session's close entry ends with a spend line. Cloud sessions can read their own figures
from `get_session` (`external_metadata.usage`); other sessions report what the client shows.
These entries are the first data SpendTracker ingests about itself.

## 13. Concurrency

Several builder sessions may run at once when their packets' file lists and table ownership
(`CAPABILITIES.md`) do not overlap. Ledger conflicts are resolved by keeping both sides; the
ledgers are append-only.

## 14. Open question: how much context a builder gets

ADR-0007 and the builder brief say builders read all context and design before touching code.
The owner has since asked that only Fable hold the full context and that builders receive their
packet plus what they need to build it. The packets in `docs/tasks/` are written to stand alone
under either rule. The choice is recorded as Q-6 in `CONTEXT.md` and belongs to the owner; when
decided it becomes a superseding ADR and a one-line change to the builder brief in
`session-start.sh`.

## 15. Changing this process

Only the owner changes this document and SESSION-PROTOCOL.md. Either role may propose a change
in its session log under a `Process proposal:` line. Fable collects proposals and puts them to
the owner at each phase close, with an ADR draft when the change is one of the decided mechanics.

# SpendTracker Development Process

This document defines how work is divided between two kinds of Claude sessions
and the contracts that connect them. Every session loads this file at start.

## 1. Roles

| | Fable session (lead) | Builder session (developer) |
|---|---|---|
| Context | Full: phases, design, architecture, diagrams, all documents, all close logs | Partial: this document, its task packet, and the code it needs to build |
| Writes code | No | Yes |
| Writes tests | Acceptance criteria and acceptance tests | Unit and integration tests for its own code |
| Runs CI | Yes, independently | Yes, locally before pushing |
| Reviews | Yes | No |
| Merges | Yes (or a human, see section 9) | Never |
| Writes docs | Design docs, phase status, decision log, review notes | Close logs, question files, assumption notes |
| Asks questions | To the human | To fable, via a question file |

### 1.1 Role is declared, never inferred

A session cannot reliably tell which model it is running on, and the serving
model can change mid-session. Therefore:

- The opening prompt of every session states its role explicitly:
  `ROLE: fable` or `ROLE: builder`.
- The session writes that role into the header of every document it produces.
- A session with no declared role must ask before doing anything else.

## 2. Context boundary

The boundary only holds if the material is physically out of reach.

- Design, phases, architecture, diagrams, and the decision log live in
  `design/` in this repo **only if** builder sessions are told not to read
  it. Preferred: keep them in a separate private location (a private docs
  repo or Drive folder) that builder sessions are never given.
- The code repo contains only what a builder needs: source, tests, this
  document, task packets, close logs, question files.
- A builder that discovers it needs something outside its packet asks for
  it. It does not go looking.

## 3. Repository layout

```
docs/
  PROCESS.md              this file
  STATUS.md               phase and task status, fable writes only
  DECISIONS.md            decision log, fable writes only
  tasks/
    T-0001-short-name.md  task packet, fable writes, builder reads
    ...
  sessions/
    YYYY-MM-DD-<role>-<short-id>.md   per-session log, any role
  questions/
    T-0001-q1.md          builder question, fable answers in place
```

Each role writes only in the locations assigned to it above. Session logs
are never edited by anyone other than the session that created them.

## 4. Task packet

Fable writes one packet per task. A builder starts with zero memory, so the
packet must stand alone. Required sections:

```
# T-0001 <short name>
ROLE: fable          AUTHOR: <session id>       SPEC-COMMIT: <hash or doc version>
PHASE: <phase name>  BRANCH: task/T-0001-short-name

## Goal
One paragraph. What exists when this is done that does not exist now.

## Acceptance criteria
Numbered, testable statements. Fable runs these. All must pass.

## Interfaces to honor
Function signatures, file formats, CLI flags, schemas the builder must not change.

## Files you may touch
Explicit list or glob. Anything else is out of scope.

## Out of scope
What not to build, even if it seems helpful.

## Tests required
What the builder must cover. Fable may attach acceptance tests here.

## Known constraints
Runtime, dependencies allowed, style rules, performance limits.
```

Multiple packets in flight at once must have disjoint "Files you may touch"
lists. Fable enforces this.

## 5. Builder session rules

1. Read this file and the assigned packet. Nothing else unless the packet
   names it.
2. Create the branch named in the packet from the current default branch.
3. Build to the acceptance criteria. Do not widen scope. Do not refactor
   outside the allowed files.
4. Write unit tests for every new code path. Run the full test suite and
   any lint or typecheck the repo defines before every push.
5. If blocked or unsure, write a question file (section 6). Then either:
   - stop, if proceeding under any assumption would waste the work; or
   - record the assumption in the session log, continue, and flag it in
     the close log.
6. Push the branch and open a draft PR referencing the task id.
7. Write the close log (section 7). Push it. End.
8. Never merge. Never edit `STATUS.md`, `DECISIONS.md`, or any packet.
9. Never modify, skip, or quarantine an existing test to get green. Report
   the failure instead.

## 6. Question protocol

- Builder writes `docs/questions/T-XXXX-qN.md` containing: the question,
  why it blocks or matters, the options it sees, and the assumption it will
  proceed under if no answer arrives.
- Builder commits and pushes the question file on its task branch.
- Fable answers by appending an `## Answer` section in the same file. If
  the answer changes the design, fable also records it in `DECISIONS.md`
  and updates the packet with a new `SPEC-COMMIT`.
- Fable escalates to the human when the answer requires a product,
  scope, or cost decision (section 10).

## 7. Close log

Written by the builder as the last act of its session at
`docs/sessions/YYYY-MM-DD-builder-<short-id>.md`. Fable treats it as a
report to verify, not as truth.

```
ROLE: builder   TASK: T-0001   BRANCH: task/T-0001-short-name   PR: <url>
SPEC-COMMIT built against: <hash>

## Result
DONE | PARTIAL | BLOCKED, with one line of explanation.

## Files changed
List.

## Tests
Tests added (names). Full suite result pasted verbatim. Lint/typecheck result.

## Acceptance criteria
For each criterion in the packet: MET | NOT MET | UNVERIFIED, with evidence.

## Assumptions made
Each one, and what would change if it is wrong.

## Deviations from packet
Anything built differently than specified, and why.

## Open questions
Links to question files still unanswered.

## Spend
Model, tokens in/out, wall-clock minutes, number of sessions, tool calls,
and any other currency this project tracks. This is the project's own
subject matter and is never omitted.
```

## 8. Fable review and verification

On each close log, fable:

1. Checks out the branch and runs the full test suite, lint, and typecheck
   itself. The close log's pasted results are not a substitute.
2. Runs the acceptance criteria from the packet.
3. Reads the diff against the "Files you may touch" list. Anything outside
   it is a finding.
4. Reads the diff for correctness, not only for green tests.
5. Records the outcome in the fable session log and updates `STATUS.md`.

Outcomes:

- **Accept**: merge per section 9. Mark the task DONE in `STATUS.md`.
- **Rework**: write a new packet `T-XXXX-r1` (same branch, same scope)
  listing each finding as a numbered acceptance criterion. Hand to a
  builder session. Repeat until accept.
- **Redesign**: the flaw is in the spec, not the build. Fable updates the
  design, records the decision, and issues a new packet with a new
  `SPEC-COMMIT`.

## 9. Branch, merge, and rollback

- One task per branch, named `task/T-XXXX-short-name`.
- Builders push only to their task branch.
- Merges to the default branch are done by fable after accept, or by the
  human if the phase gate in section 10 requires it.
- Merge strategy: merge commit, no force-push, no history rewriting on any
  branch a builder has pushed to.
- If a merged task breaks the default branch, fable reverts it immediately
  and writes a rework packet. The revert is never left to the builder.

## 10. What fable may and may not edit

Fable may edit: everything under `docs/` except builder session logs and
the body of a builder's question (fable appends answers only), CI workflow
files, repo configuration such as lint and formatter settings, and test
fixtures that define acceptance tests.

Fable may not edit: application source code or builder-written tests.
Every code change, including one-line fixes, goes through a packet to a
builder session.

Exception: if the default branch is broken and no builder session can be
started, fable may revert the offending merge (section 9). It may not
patch forward.

## 11. Human decision rights

These require the human, and fable stops and asks:

- Completing a phase and starting the next.
- Any change to architecture, interfaces, or scope recorded in the design.
- Any decision that changes the cost profile of the project.
- Adding a new dependency or external service.
- A builder's disagreement with a packet that fable cannot resolve from the
  design.
- Changing this document.

Everything else fable decides and records in `DECISIONS.md`.

## 12. Status source of truth

`docs/STATUS.md` is the only place phase and task state lives. Fable writes
it. Format:

```
## Phase <n>: <name>   STATE: NOT STARTED | IN PROGRESS | GATE | DONE
| Task | State | Branch | Builder log | Fable review |
| T-0001 | DONE / IN REVIEW / REWORK / IN PROGRESS / QUEUED | ... | ... | ... |
```

Builders report state in close logs. They never touch this file.

## 13. Session log

Every session, both roles, writes `docs/sessions/YYYY-MM-DD-<role>-<short-id>.md`
before ending. Builder logs follow the close log format in section 7.
Fable logs record: packets issued, reviews done and their outcome, decisions
made, questions answered, questions escalated, and spend for the session.

## 14. Spend

Every session log ends with a spend section. Minimum fields: model, input
tokens, output tokens, wall-clock minutes, tool calls, and session count.
These logs are the first data source SpendTracker itself will ingest.

## 15. Changing this process

Only the human changes this document. Either role may propose a change by
writing it in its session log under `## Process proposal`. Fable collects
proposals and presents them to the human at each phase gate.

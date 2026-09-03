# ADR-0010: Builder sessions work from a task packet; only the Fable session holds the full context

**Status:** Accepted — 2026-09-03. Resolves Q-6. Supersedes the 2026-09-03 phase-0c rule that
builder sessions read all context and design before touching code.

## Context

The Fable session is the architect, reviewer and gate; builder sessions (other models) build one
piece each. On 2026-09-03 the owner asked twice that only the Fable session hold the full context
and that builders receive their packet plus what they need to build it, for two reasons:

- **Quality.** A builder that reads the whole design reinterprets it. A builder that reads a packet
  builds to acceptance criteria, in the packet's order, and asks when something is missing. Its
  context window holds the packet, not the history of the project.
- **Security.** Builder sessions run on less capable, less trusted models and, in the cloud, act
  under the owner's identity. Limiting what they see (other builders' unreviewed branches, the
  decisions log, owner next actions, other packets) limits what a confused or misdirected session
  can act on, and keeps unreviewed content from one branch out of another session's context.

## Decision

- **Builder context** is exactly: `docs/PROCESS.md`, its task packet (`docs/tasks/BS-nnn-*.md`),
  the documents and sections the packet lists in the order it lists them, and what the
  `SessionStart` hook injects: the `CONTEXT.md` current-state table, the builder's own queue entry,
  open known issues, questions answered on its branch, and its own earlier log entries on that
  branch. Nothing else unless the packet names it. A builder that needs more asks with `ask.sh`
  rather than going looking.
- **Fable context** is everything: every document, ledger, branch, packet and PR.
- **Packets** are written by the Fable session, one per queue entry, before the entry is `open`,
  and stand alone (PROCESS.md § 3). An entry without a packet file is specified by its queue entry
  text alone.
- **Enforcement.** The `SessionStart` hook resolves the builder's entry (the `in progress` entry on
  its branch, else the first `open` one), stores it in the session state and injects only that
  entry; the `PreToolUse` hook denies a builder reading or editing any other packet, all ledger
  writes and all merges. Reading design documents outside the packet's list is not denied by hook
  (they live in the same repository); it is a rule the brief states and the Fable review checks
  when a PR strays outside its packet.

## Consequences

- Packet quality is the bottleneck: what the packet omits, the builder must ask for. Fable writes
  packets with the interfaces, file list, checkpoints and reading list a stranger needs.
- The 40-prompt limit and the narrow context reinforce each other: less to read, more to build.
- `CONTEXT.md` keeps owner and Fable material (next actions, decisions, questions, history) that
  builders never see; the current-state table and the queue entries are the builder-facing part.
- The builder brief in `session-start.sh`, SESSION-PROTOCOL.md, PROCESS.md and the phase playbook
  are changed together with this ADR so no document still tells a builder to read everything.

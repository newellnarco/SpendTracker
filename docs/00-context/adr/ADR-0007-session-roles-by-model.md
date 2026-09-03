# ADR-0007: Session roles are bound to the model and enforced by hooks

**Status:** Accepted — 2026-09-03

## Context

Work on this repository is done by many short Claude Code sessions with different models. The owner
wants a clear division: the most capable model (Fable) reviews, answers questions, curates the
ledgers, verifies CI and merges; other models build one piece at a time on their own PRs and only
ask, report and log. No session should run past 40 prompts, every PR is opened under the owner's
GitHub username, and every session must leave its questions, issues and progress in the repository
for the next Fable session.

## Decision

- Role is derived from the `model` reported at `SessionStart` (`fable|mythos` → Fable, else
  builder) and bound for the life of the session; model switches are blocked.
- Questions, known issues and progress live in three append-only ledger files in
  `docs/00-context/` plus the existing `CONTEXT.md`, written only through helper scripts by role.
- Hooks enforce the merge, push, edit and prompt-limit rules; CI enforces the PR-author rule.
- The Fable session is the only writer of `CONTEXT.md`, replacing "every phase updates
  CONTEXT.md" in PHASE-PLAYBOOK step 8 with "builders log and ask; Fable updates the ledger".

## Consequences

- Review and merge quality is concentrated in one model; builder throughput scales with sessions.
- Cost: every merge costs a Fable session. Acceptable to the owner; SpendTracker itself will show it.
- The hooks are guardrails, not a sandbox; branch protection on `main` is the backstop.
- Builder work must be sized to 40 prompts. `CONTEXT.md` next actions are written at that size.
- Hooks apply to every session in the repo including the one that authored them.

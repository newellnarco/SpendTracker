# ADR-0009: Session role from the observed model, else by declaration; undeclared fails closed

**Status:** Accepted — 2026-09-03. Supersedes the role-binding decision of ADR-0007 (the rest of
ADR-0007 stands). Supersedes the "declared, never inferred" proposal of PR #6.

## Context

ADR-0007 bound a session's role to the model the platform reports at `SessionStart`. In the cloud
environment the hook receives no model: every session that started on 2026-09-03 (the design
session, `858bf604`, `ac98103e`, `475ebbee`) was recorded with model `unknown`, classed as a
builder, and the Fable sessions had to correct their own state by hand after confirming the model
with `get_session`. The mechanism worked as designed only where the platform exposes the model.

PR #6 proposed the opposite rule: the role is declared in the opening prompt (`ROLE: fable` or
`ROLE: builder`), never inferred, and a session that declares nothing is undeclared and fails
closed. It accepted that a declaration is self-reported and moved the real enforcement to branch
protection on `main`.

The owner's intent behind the roles is that **different models check and gate each other's work**.
Where the model is observable it is the strongest evidence of the role and should not be
discarded; where it is not, the protocol still needs a defined, fail-closed path.

## Decision

The role of a session is determined once, at start, in this order of precedence, and recorded in
`.claude/state/sessions/<id>.json` together with its source:

| Precedence | Source | Rule |
| --- | --- | --- |
| 1 | `SPENDTRACKER_ROLE` in the process environment | owner override for one session (`env`) |
| 2 | the model reported at `SessionStart` | matches `fable_model_pattern` (`fable\|mythos`) → Fable, any other model → builder (`model`) |
| 3 | no model reported | **undeclared** until the first prompt containing `ROLE: fable` or `ROLE: builder` (`prompt`) |

- An undeclared session **fails closed**: every builder restriction applies (no merge, no push to a
  protected branch, no ledger write, no other packet), and the hooks tell it to establish its role
  before anything else: from `get_session` in cloud sessions, otherwise by asking the owner.
- A role observed from the model or set by the owner is never changed by a prompt; a `ROLE:`
  declaration that contradicts it is ignored and reported. The first declaration in an undeclared
  session binds for the life of the session.
- A Fable role declared from a prompt is marked `fable (declared)` in every session-log entry it
  writes. The session must confirm the model with `get_session` and record it in its start entry.
- Model switches stay blocked: the role's evidence is the starting model or the first declaration.

## Consequences

- The hooks give the right role wherever the model is visible and a defined, restricted state where
  it is not; no session is silently a builder any more.
- A declaration is self-reported, so branch protection on `main` (`.github/rulesets/`) is the
  backstop for merges, and the Fable review audits the session log: a `fable (declared)` entry
  whose recorded model does not match `fable|mythos` is a protocol violation.
- Two entries in the log line and state (`role_source`) make every role decision auditable.
- PR #6 is superseded by the hooks that implement this ADR; its fail-closed default, prompt
  declaration and `st_state_set` fix are carried over.

## Alternatives considered

- **Declaration only (PR #6).** Simple and honest about self-reporting, but throws away the model
  evidence where the platform provides it and lets any session claim Fable.
- **Inference only (ADR-0007 as written).** Correct where the model is reported; unusable in cloud
  sessions, which is where most work happens.

# ADR-0003: Keep list, reported and effective cost as separate cost kinds

**Status:** Accepted — 2026-09-02

## Context

Under a flat subscription (Claude Max, Copilot Pro, CodeRabbit Pro seat) the marginal cost of one
more request is zero until an allowance is exhausted, yet the tools still report a list-price
equivalent (Claude Code's `cost_usd`). Users need both numbers: list cost shows what the subscription
saved and drives "should we switch to API billing" decisions; effective cost is what the budget
actually consumed.

## Decision

`cost_line` has a `cost_kind` column with these values:

| Kind | Meaning | Produced by |
| --- | --- | --- |
| `list` | quantity × rate-card price at the event time | pricer, always |
| `reported` | amount the source supplied | pricer, when a `cost.reported.*` event exists |
| `allocated` | share of a subscription fee | pricer, for covered events |
| `overage` | usage beyond included allowance × overage rate | pricer, for covered events past the allowance |

Effective cost is a view: `allocated + overage` where a subscription covers the event, otherwise
`reported` if present, otherwise `list`.

Cost lines are derived data. `st reprice --from DATE` deletes and recomputes them; usage events are
never touched.

## Consequences

- Rate cards and subscriptions can be corrected after the fact and history re-priced.
- The UI must always label which kind a number is. Default charts show effective cost with list
  cost as a secondary series.
- Allocation methods are pluggable (see COST-MODEL.md); the default is usage share by list cost.

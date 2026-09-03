# Branch protection for `main`

`main` is the backstop the session hooks cannot enforce (SESSION-PROTOCOL.md, "What the hooks
cannot enforce"). These files are the ruleset that turns it on. Rulesets cannot be created from a
Claude Code session, so the owner applies one of them by hand.

| File | Apply when |
| --- | --- |
| `main-protection.json` | Now. Pull request required, no direct pushes, no force pushes, no deletion. No required status checks. |
| `main-protection-with-checks.json` | After slice S0 installs `examples/ci/ci.yml` as `.github/workflows/ci.yml` and one PR has run it green. Adds the eight required checks from CI-CD.md. |

## Apply

Settings → Rules → Rulesets → New ruleset → Import a ruleset → upload the JSON → Create.

Or, from a terminal with `gh` authenticated as the owner:

```sh
gh api repos/newellnarco/SpendTracker/rulesets \
  --method POST --input .github/rulesets/main-protection.json
```

To move to the checks version later, update the existing ruleset rather than creating a second one:

```sh
gh api repos/newellnarco/SpendTracker/rulesets            # note the id
gh api repos/newellnarco/SpendTracker/rulesets/<id> \
  --method PUT --input .github/rulesets/main-protection-with-checks.json
```

## Why the settings are what they are

- **Required status checks are held back.** `.github/workflows/` does not exist on `main` yet; the
  workflows live in `examples/ci/`. A required check that no workflow reports never turns green, so
  enabling the checks now would make every PR unmergeable, including the one that installs `ci.yml`.
  Q-5 already recorded this shape of problem for PRs #1 and #2.
- **`required_approving_review_count` is 0.** Every PR is opened under the owner's username (hard
  rule, SESSION-PROTOCOL.md), and GitHub does not let an author approve their own PR. Any value
  above 0 deadlocks a single-maintainer repository. The PR requirement itself, not an approval
  count, is what stops direct pushes to `main`.
- **`bypass_actors` is empty.** Builder sessions act as the owner, so an admin bypass would hand
  them the direct push to `main` that the hooks deny. For a genuine emergency, set the ruleset's
  enforcement to `disabled` in the UI, do the work, and set it back to `active`.
- **PR author restriction** is not expressible as a ruleset rule; it stays the `pr-author` CI job.

---
name: close-out
description: End a builder session cleanly. Use before the prompt limit or whenever the piece of work is done or blocked. Logs the close entry, files open questions and known issues for the Fable session, pushes the branch, ensures a draft PR exists under the owner's GitHub username, then stops.
---

# Close-out (builder sessions)

Your session id is in the SessionStart context (`Session id:`). Use it as `<sid>` below.

1. **Summarize** in three to eight lines: which queue entry (`BS-nnn` in `CONTEXT.md`) you worked and whether its exit criteria are met, what was built, what was tested and how (which CI tiers ran: unit, integration, system), what is unfinished, what blocked you.
2. **File every open question** you could not resolve, one per call:
   `.claude/hooks/ask.sh --session <sid> "question" --context "what depends on the answer"`
3. **Record every issue you found or hit** (a failing check, a bug you noticed, a flaky test), one per call, so no later session reproduces it:
   `.claude/hooks/issue.sh --session <sid> "one-line title" --check "unit|integration|system|other" --paths "src/x.py,tests/test_x.py" --detail "error signature or repro"`
4. **Commit and push** your `work/*` branch. Never push to main.
5. **Ensure a draft PR exists** for the branch, opened under the owner's GitHub username (see the hard rule in `docs/02-delivery/SESSION-PROTOCOL.md`). Use the GitHub MCP `create_pull_request` with `draft: true`. The PR body lists the summary from step 1, the question ids from step 2 and the issue ids from step 3.
6. **Log the close entry** (this marks the session closed):
   `.claude/hooks/log.sh --session <sid> close "BS-nnn: <summary>, PR #<n>, questions: <ids>, issues: <ids>"`
7. **Stop.** Do not start new work. The next Fable session reviews, answers and merges.

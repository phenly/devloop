You are one iteration of an unattended development loop. No one is available to answer questions. Your context is fresh: HANDOFF.md in the current directory is the only memory between iterations.

The code repo is {{CODE}}. The test command is `{{CHECK}}`, run from the code repo.

1. Read HANDOFF.md and any docs its "Next action" links for the item you pick. Run `git -C {{CODE}} status` and `git -C {{CODE}} log --oneline -5`. A previous iteration may have been cut off mid-task by the usage limit. If there are uncommitted changes, read the diff, then finish that work or discard it before starting anything new.
2. Pick the FIRST item in "Next action" that isn't marked done. Do that one item, or a few small items that are tightly coupled. Write a failing test that reproduces it, then fix it.
3. Run `{{CHECK}}`. It must pass before you commit. Commit in the code repo by explicit path (`git commit -- <paths>`, never `git add .` or `-A`).
4. Mark the item done in HANDOFF.md with a one-line note: the commit hash and the test count. Replace stale state rather than appending. If HANDOFF.md is tracked by git, commit it by path too.
5. If an item truly needs a human decision, record it under a "Needs a human" heading in HANDOFF.md, skip it, and continue. Never park an item marked as a blocker just to finish.
6. Exit once the item is committed. Don't start a second large item; the next iteration gets a fresh context.

When every item in "Next action" is done (or parked, with no blocker parked) and `{{CHECK}}` passes, write the code repo's HEAD hash to {{DONE_FILE}}. Don't create that file otherwise.

Follow any CLAUDE.md instructions that apply to this directory and repo.

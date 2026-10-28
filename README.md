# devloop

Finish a software project unattended, without context rot.

A Claude Code session can't clear its own context, and a long session degrades as it fills up. `devloop` works around that from outside. It runs one fresh `claude -p` session per work item, and the project's `HANDOFF.md` is the only memory carried between sessions. It reads the Claude 5-hour usage window, sleeps through each reset and keeps going.

## How it works

Each iteration starts a new session with a prompt (`prompt-template.md`) that tells it to:

1. Read `HANDOFF.md` and pick the first item under "Next action" not marked done. If a previous session was cut off mid-task, finish or discard its work first.
2. Write a failing test, fix the item, run the check command and commit by path.
3. Mark the item done in `HANDOFF.md`, then exit.
4. Once every item is done and the check passes, write the code repo's HEAD hash to a done-marker file.

Between iterations, `devloop`:

- reads `session.used_pct` from the budget file and sleeps while usage is at or above `--stop-pct` (default 98);
- counts it as progress when the code repo's HEAD or `HANDOFF.md` changed. It stops after `--stall` iterations in a row with neither (default 3);
- backs off when a session exits within two minutes, which usually means the usage limit was hit;
- stops after `--max-iter` iterations (default 40).

After the done marker appears, it runs the check itself, then the optional `--after` command, for example a smoke run of the finished software.

**The `--after` command must fail when no real work happened.** A clean exit with nothing done is not evidence. The first project this ran on had a dry-run that passed while doing nothing.

## Usage

```sh
caffeinate -i devloop --project ~/path/to/project-folder --check ./check.sh \
  --after './app smoke-test && ./verify-it-did-something'
```

- `--project`: where each session starts. It must contain `HANDOFF.md`, whose "Next action" section is the work list.
- `--code`: the code repo. Default: `<project>/CODE` if it exists, otherwise the project itself.
- `--state`: logs, per-iteration output and the done marker. Default: `~/.local/state/devloop/<project name>/`.
- `--prompt`: your own template. It can use `{{CODE}}`, `{{CHECK}}` and `{{DONE_FILE}}`.

To run it detached from the terminal: `nohup caffeinate -i devloop … > /dev/null 2>&1 &!`. `caffeinate -i` keeps the Mac awake, but not with the lid closed. Stop it with `pkill -f devloop`.

Environment:

- `DEVLOOP_CLAUDE`: the claude binary.
- `DEVLOOP_BUDGET`: the budget JSON, shaped `{"session": {"used_pct": N}}`. Default: `~/.claude/budget/claude-budget.json`, written by a separate budget daemon.
- `DEVLOOP_SLEEP_S`, `DEVLOOP_BACKOFF_S`: how long to wait between budget checks, and how long to back off after a quick exit.

Exit codes: 0 finished, 2 stalled, 3 hit max iterations, 4 check failed after done, 5 `--after` failed, 64 bad usage, 66 missing input.

## Safety

Sessions run with `--dangerously-skip-permissions`: nothing can approve a prompt at 3am. Run it only on a project you'd let an agent change freely, ideally in a repo with clean history so every change is a reviewable commit.

## Tests

```sh
zsh tests/run.sh
```

The tests run the loop end to end against a fake `claude` (`tests/fake_claude`) and a throwaway project. They cover:

- reaching done;
- one commit per iteration;
- the stall stop;
- the usage-limit backoff;
- max iterations;
- the final check failing;
- `--after` failing;
- waiting for a budget reset;
- a missing `HANDOFF.md`;
- template paths reaching the session.

Requires macOS (`md5 -q`), zsh, git and python3.

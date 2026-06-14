# Claude Code hooks

These hooks run automatically when Claude Code is the one driving
`git commit` / `git push` in this repo. They enforce two workflow
rules the team kept needing to remind the assistant about:

| Hook | Trigger | Behavior |
| --- | --- | --- |
| `check_rubocop_staged.sh` | `PreToolUse` on `Bash` containing `git commit` | Runs `bundle exec rubocop` on staged `.rb` files. Blocks the commit (exit 2) if any offenses remain. |
| `check_coveralls_pr.sh` | `PostToolUse` on `Bash` containing `git push` | If the current branch has an open PR and coveralls has reported on at least one build, prints per-file coverage for every Ruby file in the diff and flags any below 100%. Non-blocking — surfaces the gaps so they can't be silently ignored. |

Wired in `.claude/settings.json` (committed). A developer who doesn't
want them can disable per-hook in their `.claude/settings.local.json`
(gitignored) or skip Claude Code entirely — these are advisory to the
assistant, not a substitute for the project's own pre-commit /
pre-push tooling.

## Why these specifically

The rubocop one is a hard block because lint failures repeatedly
slipped to CI even though `bundle exec rubocop` takes a second to
run locally. Blocking the commit forces the fix into the same turn
that wrote the offending code.

The coveralls one is non-blocking and runs after push because
coveralls only has data for builds that have completed — there's
nothing to check before the first push that creates the PR, and the
just-pushed commit's data isn't ready yet either. What it CAN do is
surface the gaps from the previous build (or the initial-CI build)
into the assistant's context after every subsequent push, so missing
coverage stops being something the human has to chase.

## Requirements

Both hook scripts assume:
- `gh` CLI authenticated against the repo
- `jq` and `python3` on PATH
- `curl` for the coveralls fetch
- The repo root is the working directory when hooks fire (Claude
  Code's default)

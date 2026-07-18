# Claude Code hooks

These hooks run automatically when Claude Code is the one driving
`git commit` / `git push` in this repo. They enforce two workflow
rules the team kept needing to remind the assistant about:

| Hook | Trigger | Behavior |
| --- | --- | --- |
| `check_rubocop_staged.sh` | `PreToolUse` on `Bash` containing `git commit` | (1) Runs `bundle exec rubocop` on staged `.rb` files. (2) If rubocop is clean, runs `bin/rails test test/style/` — codebase-wide style rules like `no_queries_in_phlex_views_test` and `no_any_phlex_props_test` that catch patterns rubocop can't see. Blocks the commit (exit 2) if either step fails. |
| `check_any_phlex_props_on_save.sh` | `PreToolUse` on `Edit` / `Write` / `MultiEdit` to a Ruby file under `app/components/` or `app/views/` | Blocks the write if the new content contains a bare `_Any` prop, `.html_safe` / `raw(...)`, or `view_context.<method>` — three flavors of Phlex-view antipattern that the style suite catches post-hoc. Catches each before the file lands instead of after CI. |
| `check_orphaned_erb_renders.sh` | `PreToolUse` on `Bash` containing `git commit` | If the staged change deletes one or more ERB action templates / partials, scans `app/` for any surviving `render("<path>")` / `render(:<action>)` / `render(action: …)` / `render(template: …)` / `render(partial: …)` call that targeted the deleted view. Blocks the commit when ERB → Phlex conversion forgets to update one of these references (the classic `ActionView::MissingTemplate` CI failure that bit every conversion PR). |
| `block_python.sh` | `PreToolUse` on `Bash` containing `python` / `python3` as a whole word | Blocks shell commands that invoke the non-Ruby scripting interpreter. The project's permission settings allowlist `ruby -rjson -e …` via a wildcard but not Python; the hook nudges ad-hoc data munging to the friction-free path. |
| `check_coveralls_pr.sh` | `PostToolUse` on `Bash` containing `git push` | If the current branch has an open PR and coveralls has reported on at least one build, prints per-file coverage for every Ruby file in the diff and flags any below 100%. Non-blocking — surfaces the gaps so they can't be silently ignored. |
| `post_checkout_lang_db.sh` | `PostToolUse` on `Bash` containing `git checkout` / `git switch` | After a branch switch that actually moved HEAD (skips file-restore checkouts), diffs the pre-switch tip against the new one. If `config/locales/en.txt` moved, runs `bin/rails lang:update` so `en.yml` reflects the new branch's translations. If any `db/migrate/*.rb` moved, runs `bin/rails db:migrate` (development) + `RAILS_ENV=test`. Non-blocking; surfaces failures with log paths so the human can rerun manually. On a successful `lang:update`, writes `en.txt`'s git blob hash to `/tmp/mo_lang_update_synced_hash` — the same cache file `check_lang_update_before_test.sh` reads — so a `rails test` run right after the checkout doesn't redundantly re-run `lang:update`. |
| `post_rebase_lang_db.sh` | `PostToolUse` on `Bash` containing `git rebase` / `git pull --rebase` | After a successful rebase (no mid-rebase conflict state), diffs ORIG_HEAD against HEAD. If `config/locales/en.txt` moved, runs `bin/rails lang:update` so `en.yml` reflects upstream translations. If any `db/migrate/*.rb` moved, runs `bin/rails db:migrate` (development) + `RAILS_ENV=test`. Non-blocking; surfaces failures with log paths so the human can rerun manually. On a successful `lang:update`, writes `en.txt`'s git blob hash to `/tmp/mo_lang_update_synced_hash` — the same cache file `check_lang_update_before_test.sh` reads — so a `rails test` run right after the rebase doesn't redundantly re-run `lang:update`. |
| `check_lang_update_before_test.sh` | `PreToolUse` on `Bash` containing `rails test` | Guards a gap the checkout/rebase hooks above don't cover: `en.txt` can end up newer than the compiled `en.yml` without a checkout or rebase ever running (e.g. a `git merge`, or a locally-edited `en.txt`). Compares `en.txt`'s current git blob hash against the hash cached in `/tmp/mo_lang_update_synced_hash` — written by this hook OR by `post_checkout_lang_db.sh` / `post_rebase_lang_db.sh` on their own successful `lang:update` runs — and only re-runs `lang:update` (which exports every locale, not just `en.txt`) when the hash actually changed. Non-blocking — auto-fixes and prints a one-line summary, so a stale locale cache never surfaces as a spurious `Symbol.missing_tags` test failure. |
| `enforce_batch_reads.sh` | `PreToolUse` on `Read` | Enforces batch-read discipline. (1) **Solo re-reads** (a file read again in its own message, >3s since the last Read call): blocked with exit 2. (2) **Re-reads within a parallel batch** (gap ≤3s since last Read — same message): silently allowed, since the file is in context alongside the other reads and the duplicate is an accident. (3) **Solo-read warning**: if the previous batch had only one new file read, warns at the start of the next batch. Bypass for context-compression: `rm /tmp/claude_reads.txt`. State is cleared on `SessionStart`. |

The wiring in `.claude/settings.json` uses a defensive
`test -x … && exec … || exit 0` shape so branches without these
script files (e.g. older branches forked before this hook landed)
silently no-op instead of erroring on every commit/push.

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
- `jq` and `ruby` on PATH
- `curl` for the coveralls fetch
- The repo root is the working directory when hooks fire (Claude
  Code's default)

(JSON parsing is in Ruby, not Python, so the inline `ruby -rjson -e`
calls match the project's existing
`Bash(ruby -rjson -e:*)` permission wildcard — no extra permission
prompt on every coveralls run.)

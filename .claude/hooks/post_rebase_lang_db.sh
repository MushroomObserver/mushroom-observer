#!/usr/bin/env bash
# Claude Code PostToolUse hook.
# Fires after a successful `Bash` call. When the command was a `git
# rebase` (or `git pull --rebase` / `git pull` that resolves to a
# rebase) that succeeded without conflicts, runs:
#
#   1. `bin/rails lang:update` if `config/locales/en.txt` changed
#      between the pre-rebase tip and the post-rebase tip. Regenerates
#      `en.yml` so any new translations introduced by upstream
#      commits are picked up before the next test run.
#
#   2. `bin/rails db:migrate` (development) and
#      `bin/rails db:migrate RAILS_ENV=test` if any
#      `db/migrate/*.rb` files changed between the two tips.
#      Otherwise the next test run errors with `PendingMigrationError`
#      and the dev server's schema drifts from main's.
#
# Non-blocking: each step prints a one-line summary on success and a
# friendly notice on failure. The user can still run them manually
# if anything looks off.
#
# Reads JSON on stdin from Claude Code; only inspects
# `tool_input.command`.
set -uo pipefail

INPUT="$(cat)"
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"

# Only act on rebases. The hook fires on every Bash call, so the
# command-pattern check is the first cheap filter.
case "$COMMAND" in
  *"git rebase"*) ;;
  *"git pull --rebase"*) ;;
  *) exit 0 ;;
esac

# A rebase that hit conflicts (mid-rebase) prints "CONFLICT" and the
# index goes into REBASE_HEAD state. Skip the post-rebase actions
# when we're still mid-rebase — the user resolves conflicts first.
GIT_DIR="$(git rev-parse --git-dir 2>/dev/null || true)"
if [ -z "$GIT_DIR" ]; then
  exit 0
fi
if [ -d "$GIT_DIR/rebase-merge" ] || [ -d "$GIT_DIR/rebase-apply" ]; then
  exit 0
fi

# Compare the working tree's tip against ORIG_HEAD — git sets
# ORIG_HEAD to the pre-rebase tip when a rebase completes. If
# ORIG_HEAD doesn't exist (rare; first-ever rebase in a fresh clone),
# fall back to the reflog's second entry.
PRE_REBASE="$(git rev-parse ORIG_HEAD 2>/dev/null || true)"
if [ -z "$PRE_REBASE" ]; then
  PRE_REBASE="$(git rev-parse HEAD@{1} 2>/dev/null || true)"
fi
POST_REBASE="$(git rev-parse HEAD 2>/dev/null || true)"

if [ -z "$PRE_REBASE" ] || [ -z "$POST_REBASE" ] ||
   [ "$PRE_REBASE" = "$POST_REBASE" ]; then
  # Nothing actually changed (e.g. branch already on top of base) —
  # no follow-up actions needed.
  exit 0
fi

CHANGED="$(git diff --name-only "$PRE_REBASE" "$POST_REBASE" 2>/dev/null || true)"

if printf '%s\n' "$CHANGED" | grep -qxF "config/locales/en.txt"; then
  echo "" >&2
  echo "🌐 rebase: en.txt changed — running bin/rails lang:update" >&2
  if bin/rails lang:update >/tmp/post_rebase_lang.log 2>&1; then
    echo "   ✅ lang:update complete (en.yml regenerated)" >&2
  else
    echo "   ⚠️  lang:update failed; see /tmp/post_rebase_lang.log" >&2
  fi
fi

if printf '%s\n' "$CHANGED" | grep -qE '^db/migrate/.*\.rb$'; then
  echo "" >&2
  echo "🗄️  rebase: new migration(s) — running bin/rails db:migrate" >&2
  if bin/rails db:migrate >/tmp/post_rebase_db_dev.log 2>&1; then
    echo "   ✅ db:migrate (development) complete" >&2
  else
    echo "   ⚠️  db:migrate (development) failed; see /tmp/post_rebase_db_dev.log" >&2
  fi
  if bin/rails db:migrate RAILS_ENV=test >/tmp/post_rebase_db_test.log 2>&1; then
    echo "   ✅ db:migrate (test) complete" >&2
  else
    echo "   ⚠️  db:migrate (test) failed; see /tmp/post_rebase_db_test.log" >&2
  fi
fi

exit 0

#!/usr/bin/env bash
# Claude Code PostToolUse hook.
# Fires after a successful `Bash` call. When the command was a branch
# switch (`git checkout <branch>` or `git switch <branch>`), runs:
#
#   1. `bin/rails lang:update` if `config/locales/en.txt` changed
#      between the old and new branch tips. Regenerates `en.yml` so
#      any translation changes on the new branch are picked up before
#      the next test run.
#
#   2. `bin/rails db:migrate` (development and test) if any
#      `db/migrate/*.rb` files changed between the two branch tips.
#
# Non-blocking: each step prints a one-line summary; failures print a
# notice so the user can run manually.
#
# Reads JSON on stdin from Claude Code; only inspects
# `tool_input.command`.
set -uo pipefail

INPUT="$(cat)"
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"

# Only act on checkout / switch commands.
case "$COMMAND" in
  *"git checkout"*) ;;
  *"git switch"*) ;;
  *) exit 0 ;;
esac

# Skip file-restore checkouts (`git checkout -- file` or
# `git checkout main -- file`). These don't change HEAD; the reflog
# entry won't exist yet, or HEAD@{1} == HEAD.
GIT_DIR="$(git rev-parse --git-dir 2>/dev/null || true)"
if [ -z "$GIT_DIR" ]; then
  exit 0
fi

PRE_SWITCH="$(git rev-parse HEAD@{1} 2>/dev/null || true)"
POST_SWITCH="$(git rev-parse HEAD 2>/dev/null || true)"

if [ -z "$PRE_SWITCH" ] || [ -z "$POST_SWITCH" ] ||
   [ "$PRE_SWITCH" = "$POST_SWITCH" ]; then
  # HEAD didn't move — file restore, detach, or no-op. Skip.
  exit 0
fi

CHANGED="$(git diff --name-only "$PRE_SWITCH" "$POST_SWITCH" 2>/dev/null || true)"

if printf '%s\n' "$CHANGED" | grep -qxF "config/locales/en.txt"; then
  echo "" >&2
  echo "🌐 branch switch: en.txt changed — running bin/rails lang:update" >&2
  if bin/rails lang:update >/tmp/post_checkout_lang.log 2>&1; then
    echo "   ✅ lang:update complete (en.yml regenerated)" >&2
  else
    echo "   ⚠️  lang:update failed; see /tmp/post_checkout_lang.log" >&2
  fi
fi

if printf '%s\n' "$CHANGED" | grep -qE '^db/migrate/.*\.rb$'; then
  echo "" >&2
  echo "🗄️  branch switch: migration(s) differ — running bin/rails db:migrate" >&2
  if bin/rails db:migrate >/tmp/post_checkout_db_dev.log 2>&1; then
    echo "   ✅ db:migrate (development) complete" >&2
  else
    echo "   ⚠️  db:migrate (development) failed; see /tmp/post_checkout_db_dev.log" >&2
  fi
  if bin/rails db:migrate RAILS_ENV=test >/tmp/post_checkout_db_test.log 2>&1; then
    echo "   ✅ db:migrate (test) complete" >&2
  else
    echo "   ⚠️  db:migrate (test) failed; see /tmp/post_checkout_db_test.log" >&2
  fi
fi

exit 0

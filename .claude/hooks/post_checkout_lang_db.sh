#!/usr/bin/env bash
# Claude Code PostToolUse hook. After a branch switch that moves
# HEAD (`git checkout`/`git switch`):
#   1. `bin/rails lang:update` if `config/locales/en.txt` changed
#      (imports translations into the DB/cache).
#   2. `bin/rails db:migrate` (dev + test) if any `db/migrate/*.rb`
#      changed.
# Non-blocking; prints failures with log paths. Reads JSON on stdin;
# only inspects `tool_input.command`.
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
    echo "   ✅ lang:update complete (DB/cache updated)" >&2
    # Shared with check_lang_update_before_test.sh, so a `rails test`
    # right after this checkout doesn't redundantly re-run lang:update.
    git hash-object config/locales/en.txt \
      > /tmp/mo_lang_update_synced_hash 2>/dev/null || true
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

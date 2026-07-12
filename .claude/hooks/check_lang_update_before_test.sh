#!/usr/bin/env bash
# Claude Code PreToolUse hook.
# Fires before `Bash` calls containing `rails test` (any form: `bin/rails
# test`, `bundle exec rails test`, `rails test:...`). Ensures
# config/locales/en.yml reflects the current config/locales/en.txt before
# the test run, so a stale compiled locale cache never causes a spurious
# Symbol.missing_tags teardown failure (test/test_helper.rb) that the
# assistant then has to spend a turn diagnosing.
#
# Cheap check, same git-diff spirit as post_checkout_lang_db.sh /
# post_rebase_lang_db.sh: compares en.txt's current git blob hash against
# the hash recorded the last time this hook successfully ran
# `bin/rails lang:update`. Only pays the real lang:update cost (it
# exports every locale, not just en.txt) when en.txt has actually
# changed since -- the common case (repeated test runs against the same
# checkout) is a single `git hash-object` call plus a cache-file read.
#
# Non-blocking: prints a one-line summary; a failure prints a notice so
# the human can rerun manually. Never blocks the test command itself.
#
# Reads JSON on stdin from Claude Code; only inspects `tool_input.command`.
set -uo pipefail

INPUT="$(cat)"
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"

# Only act on rails test invocations.
case "$COMMAND" in
  *"rails test"*) ;;
  *) exit 0 ;;
esac

GIT_DIR="$(git rev-parse --git-dir 2>/dev/null || true)"
if [ -z "$GIT_DIR" ]; then
  exit 0
fi

if [ ! -f config/locales/en.txt ]; then
  exit 0
fi

CACHE_FILE="/tmp/mo_lang_update_synced_hash"
CURRENT_HASH="$(git hash-object config/locales/en.txt 2>/dev/null || true)"
if [ -z "$CURRENT_HASH" ]; then
  exit 0
fi

CACHED_HASH="$(cat "$CACHE_FILE" 2>/dev/null || true)"

if [ "$CURRENT_HASH" = "$CACHED_HASH" ]; then
  exit 0
fi

echo "" >&2
echo "🌐 en.txt changed since last sync — running bin/rails lang:update" >&2
if bin/rails lang:update >/tmp/pre_test_lang_update.log 2>&1; then
  echo "$CURRENT_HASH" > "$CACHE_FILE"
  echo "   ✅ lang:update complete (en.yml regenerated)" >&2
else
  echo "   ⚠️  lang:update failed; see /tmp/pre_test_lang_update.log" >&2
fi

exit 0

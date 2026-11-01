#!/usr/bin/env bash
# Claude Code PreToolUse hook. Fires before a `rails test` Bash call.
# Regenerates en.yml from en.txt first if stale, so a Symbol.missing_tags
# teardown failure doesn't cost the assistant a turn diagnosing it.
# Cache key is en.txt's git blob hash + branch name (see
# script/lang_update_if_needed.sh for why branch is part of the key).
# Non-blocking: never blocks the test command itself, just reports.
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
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")"
FILE_HASH="$(git hash-object config/locales/en.txt 2>/dev/null || true)"
if [ -z "$FILE_HASH" ]; then
  exit 0
fi
CURRENT_HASH="$FILE_HASH-$CURRENT_BRANCH"

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

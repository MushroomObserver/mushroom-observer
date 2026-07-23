#!/usr/bin/env bash
#
# Runs `rake lang:update` only when config/locales/en.txt has changed
# since the last time this script ran it successfully. lang:update's
# import-into-DB + regenerate-every-locale pipeline costs several
# seconds and is pure overhead on a deploy that doesn't touch
# translations -- the common case. Safe specifically because this is a
# skip-ON-NO-CHANGE optimization, not a switch to checked-in generated
# locale files: production's translations DB (edited live via the
# translations UI) is untouched either way, so there's no risk of an
# unrelated deploy silently reverting a live translation edit. When
# en.txt HAS changed, lang:update still runs exactly as before.
#
# Cache file lives in tmp/ (not /tmp) so it survives alongside the
# checkout it was computed for, the same way Rails' own tmp/ artifacts
# do -- not committed (tmp/ is gitignored), not shared across checkouts.
set -euo pipefail

if [ ! -f config/locales/en.txt ]; then
  echo "config/locales/en.txt not found -- running lang:update to be safe"
  exec rake lang:update
fi

CACHE_FILE="tmp/lang_update_synced_hash"
CURRENT_HASH="$(git hash-object config/locales/en.txt)"
CACHED_HASH="$(cat "$CACHE_FILE" 2>/dev/null || true)"

if [ "$CURRENT_HASH" = "$CACHED_HASH" ]; then
  echo "en.txt unchanged since last successful lang:update -- skipping"
  exit 0
fi

rake lang:update
echo "$CURRENT_HASH" > "$CACHE_FILE"

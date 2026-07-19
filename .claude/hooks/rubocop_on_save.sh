#!/usr/bin/env bash
# Claude Code PostToolUse hook.
# Fires after `Edit` / `Write` / `MultiEdit`. Runs
# `bundle exec rubocop --autocorrect-all` on the just-saved Ruby file
# so format/lint fixes happen automatically (the way a VS Code "format
# on save" extension would do it).
#
# Scope: only Ruby files (`.rb`) under the project tree. The autocorrect
# always lands silently. If any uncorrectable offenses remain (e.g.
# Metrics/AbcSize, Lint/UselessAssignment, Layout/LineLength on a line
# Rubocop can't auto-wrap), they're printed to stderr so Claude sees
# them in the tool result — the only way line-length offenses actually
# register as something to fix instead of getting deferred to commit time.
set -euo pipefail

INPUT="$(cat)"
TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')"
case "$TOOL" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""')"
case "$FILE" in
  *.rb) ;;
  *) exit 0 ;;
esac

# Skip files outside the project (e.g. /tmp scratch).
case "$FILE" in
  */mushroom-observer/*) ;;
  *) exit 0 ;;
esac

# Skip db/schema.rb -- it's auto-generated (no style discipline
# applied to it) and .rubocop.yml already excludes "db/**/*", but
# RuboCop's Exclude only applies to auto-discovered targets, not
# files passed explicitly on the command line, so this hook has to
# honor the same exclusion itself for schema.rb specifically.
# Without this, invoking rubocop directly on it triggers a full-file
# autocorrect (adds frozen_string_literal, reflows every create_table
# line, etc.) on top of whatever one-line hand-edit prompted the save
# -- a huge, unreviewable diff unrelated to the actual change.
# Migrations (db/migrate/*) are NOT excluded here -- they're
# hand-written code and still expected to pass rubocop normally.
case "$FILE" in
  */db/schema.rb) exit 0 ;;
esac

# Skip files that don't exist (the tool may have failed to write).
[ -f "$FILE" ] || exit 0

cd "$(git -C "$(dirname "$FILE")" rev-parse --show-toplevel 2>/dev/null || \
      pwd)"

# Autocorrect silently. If offenses remain after autocorrect, print
# them so the model sees them in the tool result.
OUTPUT="$(bundle exec rubocop --autocorrect-all --format simple "$FILE" 2>&1 || true)"

# Re-check the file after autocorrect — anything still flagged needs
# manual attention.
REMAINING="$(bundle exec rubocop --format simple "$FILE" 2>&1 || true)"

if printf '%s' "$REMAINING" | grep -qE '^[CWE]:[[:space:]]'; then
  cat >&2 <<EOF
⚠️  Rubocop autocorrected what it could, but offenses remain on
$FILE — fix before moving on:

$REMAINING
EOF
  # Exit 2 surfaces the message to the model. Non-blocking — the file
  # is already written; this is just a flag.
  exit 2
fi

exit 0

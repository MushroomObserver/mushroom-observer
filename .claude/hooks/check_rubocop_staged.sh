#!/usr/bin/env bash
# Claude Code PreToolUse hook.
# Fires before `Bash` calls. If the command is a `git commit`, runs
# rubocop on staged Ruby files. Exits 2 (blocking) if any offenses
# are found so the agent can't commit lint-broken Ruby.
#
# Reads JSON on stdin from Claude Code; only inspects `tool_input.command`.
set -euo pipefail

INPUT="$(cat)"
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"

# Only interested in git commit. Skip everything else.
case "$COMMAND" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

# Collect staged Ruby files (Added / Copied / Modified / Renamed).
STAGED="$(git diff --cached --name-only --diff-filter=ACMR | grep -E '\.rb$' || true)"
if [ -z "$STAGED" ]; then
  exit 0
fi

# Run rubocop only on those files.
OUTPUT="$(bundle exec rubocop --format simple $STAGED 2>&1 || true)"

# Pass if rubocop says "no offenses". Otherwise block.
if printf '%s' "$OUTPUT" | grep -qE "no offenses detected"; then
  exit 0
fi

cat >&2 <<EOF
🚫 Rubocop offenses on staged Ruby files — blocking commit.

$OUTPUT

Run \`bundle exec rubocop --autocorrect-all <files>\` to fix, re-stage,
then commit again.
EOF
exit 2

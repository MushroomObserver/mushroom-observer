#!/usr/bin/env bash
# Claude Code PreToolUse hook.
# Fires before `Bash` calls. If the command is a `git commit`, runs:
#  1. `bundle exec rubocop` on staged Ruby files.
#  2. The project's style test suite (`test/style/`), which catches
#     codebase-wide violations rubocop doesn't know about
#     (no-queries-in-phlex-views, no-bare-_Any-phlex-props, etc.).
# Exits 2 (blocking) if either step fails.
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

# Step 1: Rubocop on the staged files only.
RUBOCOP_OUT="$(bundle exec rubocop --format simple $STAGED 2>&1 || true)"
if ! printf '%s' "$RUBOCOP_OUT" | grep -qE "no offenses detected"; then
  cat >&2 <<EOF
🚫 Rubocop offenses on staged Ruby files — blocking commit.

$RUBOCOP_OUT

Run \`bundle exec rubocop --autocorrect-all <files>\` to fix, re-stage,
then commit again.
EOF
  exit 2
fi

# Step 2: project style test suite. Catches no-queries-in-phlex-views,
# no-bare-_Any-phlex-props, etc. — codebase-wide rules a per-file
# rubocop run can't see. Skip silently if `test/style/` doesn't exist
# on the current branch.
if [ ! -d test/style ]; then
  exit 0
fi

STYLE_OUT="$(bin/rails test test/style/ 2>&1 || true)"
if ! printf '%s' "$STYLE_OUT" | grep -qE "0 failures, 0 errors"; then
  cat >&2 <<EOF
🚫 Style test failures — blocking commit.

$STYLE_OUT

Fix the violations before committing. (Codebase-wide style rules
like \`no_queries_in_phlex_views_test\` and \`no_any_phlex_props_test\`
catch patterns rubocop can't see.)
EOF
  exit 2
fi

exit 0

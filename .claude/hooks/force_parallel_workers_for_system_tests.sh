#!/usr/bin/env bash
# Claude Code PreToolUse hook.
# Fires on the `Bash` tool. When Claude tries to run system tests
# (`bin/rails test test/system/...`), require the command to be
# prefixed with `PARALLEL_WORKERS=1`. MO's Capybara + Cuprite system
# tests are flaky under the default parallel-workers count (per the
# user's instructions and `feedback_keep_system_tests_green`); forcing
# the single-worker mode at hook time prevents the model from
# burning a 15-30 minute run on a parallelism-induced flake.
#
# Also blocks the `rails test:system` form entirely: per CLAUDE.md,
# that runs the WHOLE system suite and silently ignores any file
# argument, which is almost never what the model wants.
set -euo pipefail

INPUT="$(cat)"
TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')"
[ "$TOOL" = "Bash" ] || exit 0

CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"

if printf '%s' "$CMD" | grep -qE '\b(bin/|bundle exec )?rails\s+test:system\b'; then
  cat >&2 <<EOF
🚫 \`rails test:system\` ignores file arguments and runs the WHOLE
system test suite (per CLAUDE.md). Use the form:

  PARALLEL_WORKERS=1 bin/rails test test/system/<file>.rb

to run a specific system test file, or omit the file argument
entirely if you really want the whole suite.
EOF
  exit 2
fi

if printf '%s' "$CMD" | grep -qE '\b(bin/|bundle exec )?rails\s+test\b.*\btest/system\b'; then
  if ! printf '%s' "$CMD" | grep -qE '\bPARALLEL_WORKERS=1\b'; then
    cat >&2 <<EOF
🚫 MO system tests must run with PARALLEL_WORKERS=1. Capybara +
Cuprite browser-driver tests are flaky under the default parallel-
workers count; running them in parallel wastes 15-30 minutes on a
flake-induced failure.

Prepend \`PARALLEL_WORKERS=1 \` to the command and re-run.
EOF
    exit 2
  fi
fi

exit 0

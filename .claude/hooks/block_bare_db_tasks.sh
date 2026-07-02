#!/usr/bin/env bash
# Claude Code PreToolUse hook.
# Fires before `Bash` calls. Blocks chaining db:drop, db:create, and
# db:schema:load together in a single rails command.
#
# Why: when chained as `bin/rails db:drop db:create db:schema:load`,
# Rails resolves the schema:load against all configured database
# environments (including the cache DB in development), causing
# foreign-key ordering errors even on a freshly created test database.
#
# Run each task separately instead:
#
#   RAILS_ENV=test bin/rails db:drop
#   RAILS_ENV=test bin/rails db:create
#   RAILS_ENV=test bin/rails db:schema:load
set -euo pipefail

INPUT="$(cat)"
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"

# Count how many db: task words appear in the command.
# Two or more of (db:drop, db:create, db:schema:load) in one command = blocked.
DB_TASK_COUNT=$(printf '%s' "$COMMAND" | grep -oE 'db:(drop|create|schema:load)' | wc -l | tr -d ' ')

if [ "${DB_TASK_COUNT:-0}" -ge 2 ]; then
  cat >&2 <<'EOF'
🚫 Don't chain db:drop / db:create / db:schema:load in one command.

When chained in a single `bin/rails` call, schema:load resolves
against all configured database environments and chokes on
cross-database foreign-key ordering.

Run each task on its own line instead:

  RAILS_ENV=test bin/rails db:drop
  RAILS_ENV=test bin/rails db:create
  RAILS_ENV=test bin/rails db:schema:load

Rewrite as three separate commands and retry.
EOF
  exit 2
fi

exit 0

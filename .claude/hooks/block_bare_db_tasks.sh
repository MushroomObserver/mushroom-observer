#!/usr/bin/env bash
# Claude Code PreToolUse hook.
# Fires before `Bash` calls. Blocks `db:drop`, `db:reset`, and
# `db:schema:load` outright -- alone or chained, in any `bin/rails`/
# `bin/rake`/`bundle exec rake` command.
#
# Why: these drop and recreate tables. MySQL DDL isn't transactional
# -- a command that fails partway through (e.g. a foreign-key error
# on one table) still leaves every table processed before the failure
# dropped and empty, even though the overall command reports failure.
# A `bin/rails db:schema:load` run that errored out on a FK constraint
# still wiped most of a local development database this way.
#
# Ask the user to run the command themselves (`! <command>` in the
# prompt) instead of retrying past this block.
set -euo pipefail

INPUT="$(cat)"
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"

# Only fire when the command actually invokes rails/rake -- not when
# the db: tokens appear in heredoc prose or a PR body being written
# to a file.
case "$COMMAND" in
  *"bin/rails"*|*"bin/rake"*|*"bundle exec rake"*) ;;
  *) exit 0 ;;
esac

if printf '%s' "$COMMAND" | grep -qE 'db:(drop|reset|schema:load)\b'; then
  cat >&2 <<'EOF'
🚫 db:drop / db:reset / db:schema:load are blocked for Claude, alone or chained.

These drop and recreate tables. MySQL DDL isn't transactional, so
even a command that fails partway through (e.g. a foreign-key error
on one table) leaves every table processed before that point dropped
and empty -- confirmed: a failed db:schema:load run wiped most of a
local development database this way.

Ask the user to run it themselves -- they can type `! <command>` in
the prompt -- rather than retrying this command.
EOF
  exit 2
fi

exit 0

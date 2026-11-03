#!/usr/bin/env bash
# Claude Code PreToolUse hook.
# Fires before `Bash` calls. Blocks running rubocop against
# config/locales/*.txt -- MO's custom key:value translation source
# files (en.txt, es.txt, etc.), not Ruby, so rubocop's parser just
# dumps a wall of Lint/Syntax noise.
set -uo pipefail

INPUT="$(cat)"
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"

# git commit bodies routinely mention "rubocop" and name
# config/locales/en.txt in prose or in a `git add` -- not an actual
# rubocop invocation. Leave commits to check_rubocop_staged.sh.
case "$COMMAND" in
  *"git commit"*) exit 0 ;;
esac

case "$COMMAND" in
  *rubocop*) ;;
  *) exit 0 ;;
esac

# Require the two to appear on the same line, close enough to read as
# one invocation (rubocop ... config/locales/en.txt), not two
# unrelated mentions anywhere in a longer command.
if printf '%s' "$COMMAND" |
   grep -qE 'rubocop[^|;&]{0,80}config/locales/[a-zA-Z_-]+\.txt'; then
  cat >&2 <<'EOF'
🚫 Don't run rubocop against config/locales/*.txt.

These are MO's custom key:value translation source files (en.txt,
es.txt, ...), not Ruby -- rubocop's parser has nothing to check and
just dumps a wall of Lint/Syntax noise. There's no lint step for this
file; edit it and run `bin/rails lang:update` instead.
EOF
  exit 2
fi

exit 0

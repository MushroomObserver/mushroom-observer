#!/usr/bin/env bash
# Claude Code PreToolUse hook, fires before `Bash` calls. Blocks any
# local SCSS compile/syntax-check attempt (assets:precompile/clobber,
# dartsass:compile/watch, a sass CLI, or a Ruby one-liner invoking a
# sass gem) -- this environment lacks the toolchain to resolve MO's
# SCSS correctly, so any attempt fails or misleads. See
# feedback_mo_asset_pipeline_vs_football_tribes.md (project memory).
set -euo pipefail

INPUT="$(cat)"
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"

BLOCK_MSG='🚫 Do not compile or syntax-check SCSS locally.

This environment does not have the node/dart-sass toolchain needed to
actually resolve MO'"'"'s SCSS (bootstrap-sass variables, theme
mapping, etc.), so any local compile/syntax-check attempt fails or
misleads rather than verifying anything. Edit the SCSS file and stop
there -- tell the user the file is saved and to reload the browser.
Do not run `assets:precompile`, `assets:clobber`, `dartsass:compile`,
a sass CLI, or a Ruby one-liner that requires a sass gem to "verify"
the change. If you genuinely suspect a syntax error, ask the user to
check their watcher/dev server output instead of trying to reproduce
it yourself.'

if printf '%s' "$COMMAND" | grep -qE '\b(assets:precompile|assets:clobber|dartsass:(compile|watch))\b'; then
  echo "$BLOCK_MSG" >&2
  exit 2
fi

if printf '%s' "$COMMAND" | grep -qE '(^|[;|&`]|\$\()[[:space:]]*(bundle[[:space:]]+exec[[:space:]]+)?(sass-embedded|sassc-embedded|sassc|dart-sass|node-sass)([^A-Za-z0-9_-]|$)'; then
  echo "$BLOCK_MSG" >&2
  exit 2
fi

if printf '%s' "$COMMAND" | grep -qE "require[[:space:]]+['\"](sass/embedded|sassc/embedded|sass_c/embedded|sassc)['\"]|Sass\.compile|SassC::Engine"; then
  echo "$BLOCK_MSG" >&2
  exit 2
fi

exit 0

#!/usr/bin/env bash
# Claude Code PreToolUse hook.
# Fires before `Bash` calls. Blocks any attempt to compile or
# syntax-check MO's SCSS locally -- this environment doesn't have the
# node/dart-sass toolchain that MO's actual SCSS (bootstrap-sass
# variables, theme mapping, etc.) needs to resolve, so any attempt
# fails or misleads rather than actually verifying anything. The user
# runs their own sass watcher (VS Code "Watch Sass" extension) and the
# dev server surfaces real compile errors on page load -- that's the
# only real verification available. See the MO SCSS workflow memory
# (project memory system, feedback_mo_asset_pipeline_vs_football_tribes.md)
# for the repeated incidents this hook backstops.
#
# Blocks: rake/rails asset tasks (assets:precompile, assets:clobber,
# dartsass:compile/watch), direct sass compiler binaries
# (sass-embedded, sassc, dart-sass, node-sass), and ad-hoc Ruby
# one-liners that require a sass gem or call Sass.compile /
# SassC::Engine directly.
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

if printf '%s' "$COMMAND" | grep -qE '(^|[;|&`]|\$\()[[:space:]]*(bin/)?rails[[:space:]]+.*(assets:precompile|assets:clobber|dartsass:(compile|watch))'; then
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

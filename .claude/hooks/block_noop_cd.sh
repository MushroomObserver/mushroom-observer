#!/usr/bin/env bash
# Claude Code PreToolUse hook.
# Fires before `Bash` calls. Blocks a command whose leading `cd`
# resolves to the directory the Bash tool is already in -- a pure
# no-op per CLAUDE.md's Shell Commands section, and one that also
# trips a separate "path resolution bypass" permission prompt when
# chained with `&&`/`;`/a newline.
#
# Deliberately conservative: only blocks when the `cd` target
# resolves (via a real `cd` builtin call, so `~`, `$HOME`, `..`, etc.
# all expand exactly like they would in the real command) to EXACTLY
# the current directory. A `cd` into any other directory -- a
# subdirectory, a sibling repo, `..`, anywhere else -- is a legitimate
# command and must never be blocked. If resolution fails or is
# ambiguous for any reason, this hook fails open (does not block)
# rather than risk a false positive.
#
# CD_ARG is derived directly from the command about to run, so it
# could be adversarial/prompt-injection-controlled -- this script
# NEVER `eval`s it or otherwise re-parses it as shell code. Only plain
# quote-stripping, an optional leading `--` end-of-options marker
# (`cd -- .` is equivalent to `cd .`), and a literal `~`/`$HOME`/`$PWD`
# prefix substitution are handled (pure string manipulation); everything
# else is passed to `cd --` as a literal argument, which resolves paths
# without executing anything from them. If CD_ARG contains command/
# process substitution syntax, this hook doesn't attempt to resolve it
# at all.
set -euo pipefail

INPUT="$(cat)"
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"

# Leading command segment only -- up to the first &&, ;, |, or newline.
# `sed` truncates at the first separator per line; `head -n1` then
# takes just the first line, which handles a same-line separator and
# a bare newline-separated second command uniformly.
FIRST_SEGMENT="$(printf '%s' "$COMMAND" |
  sed -E 's/(&&|;|\|).*//' | head -n1 |
  sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"

# Only a bare `cd <arg>` as the very first thing the command does.
if ! printf '%s' "$FIRST_SEGMENT" | grep -qE '^cd[[:space:]]+[^[:space:]]'; then
  exit 0
fi

CD_ARG="$(printf '%s' "$FIRST_SEGMENT" |
  sed -E 's/^cd[[:space:]]+//; s/^--[[:space:]]+//')"

# Refuse to interpret anything that could execute code if evaluated
# further (command substitution, process substitution). Fail open --
# don't attempt resolution, don't block -- rather than risk running
# attacker/prompt-injection-controlled shell syntax inside this hook.
if printf '%s' "$CD_ARG" | grep -qE '`|\$\(|<\(|>\('; then
  exit 0
fi

# Strip one layer of matching quotes, if present.
UNQUOTED="$CD_ARG"
case "$UNQUOTED" in
  \"*\") UNQUOTED="${UNQUOTED#\"}"; UNQUOTED="${UNQUOTED%\"}" ;;
  \'*\') UNQUOTED="${UNQUOTED#\'}"; UNQUOTED="${UNQUOTED%\'}" ;;
esac

CURRENT="$(pwd -P)"

# The only expansions handled: a literal leading `~`, `$HOME`, or
# `$PWD` -- pure string substitution, never executed. Everything else
# (absolute paths, relative paths, `..`) needs no expansion at all;
# `cd` resolves those itself when given the literal argument below.
case "$UNQUOTED" in
  "~"|"~/"*) UNQUOTED="${HOME}${UNQUOTED#\~}" ;;
  "\$HOME"|"\$HOME/"*) UNQUOTED="${HOME}${UNQUOTED#\$HOME}" ;;
  "\$PWD"|"\$PWD/"*) UNQUOTED="${CURRENT}${UNQUOTED#\$PWD}" ;;
esac

# Resolve the target in a subshell (no effect on this script's own
# cwd) via a real `cd` builtin call with UNQUOTED passed as a literal
# argument -- never re-parsed as shell code, so nothing in it can
# execute regardless of its contents.
RESOLVED="$(cd -- "$UNQUOTED" 2>/dev/null && pwd -P || true)"

if [ -n "$RESOLVED" ] && [ "$RESOLVED" = "$CURRENT" ]; then
  cat >&2 <<EOF
🚫 Leading \`cd\` resolves to the current directory -- blocking as a no-op.

Command: $COMMAND

Bash calls already start in the session's working directory
($CURRENT) and it persists across every call, so \`cd\`-ing back to
it accomplishes nothing except (when chained with &&/;) tripping a
separate "path resolution bypass" approval prompt. Drop the leading
\`cd\` and run the rest of the command directly.

If this \`cd\` genuinely targets a DIFFERENT directory and this is a
false positive, tell the user -- they can adjust or bypass this hook.
EOF
  exit 2
fi

exit 0

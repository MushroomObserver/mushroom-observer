#!/usr/bin/env bash
# Claude Code PreToolUse hook.
# Fires before `Bash` calls. Blocks a command whose leading `cd`
# resolves to the directory the Bash tool is already in -- a pure
# no-op per CLAUDE.md's Shell Commands section, and one that also
# trips a separate "path resolution bypass" permission prompt when
# chained with `&&`/`;`/a newline.
#
# Deliberately conservative: only blocks when the `cd` target
# resolves (via a real subshell `cd`, so `~`, `$HOME`, `..`, etc. all
# expand exactly like they would in the real command) to EXACTLY the
# current directory. A `cd` into any other directory -- a subdirectory,
# a sibling repo, `..`, anywhere else -- is a legitimate command and
# must never be blocked. If resolution fails or is ambiguous for any
# reason, this hook fails open (does not block) rather than risk a
# false positive.
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

CD_ARG="$(printf '%s' "$FIRST_SEGMENT" | sed -E 's/^cd[[:space:]]+//')"

# Resolve the target in a subshell (no effect on this script's own
# cwd) via a real `cd`, so quoting/`~`/`$HOME`/relative-path expansion
# all match actual shell semantics instead of being reimplemented here.
CURRENT="$(pwd -P)"
RESOLVED="$(eval "cd -- ${CD_ARG} 2>/dev/null && pwd -P" 2>/dev/null || true)"

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

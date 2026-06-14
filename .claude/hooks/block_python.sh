#!/usr/bin/env bash
# Claude Code PreToolUse hook.
# Fires before `Bash` calls. Blocks commands that invoke `python3`
# (or `python`) so the assistant defaults to Ruby for ad-hoc JSON /
# data-munging one-liners.
#
# Why: the project's `.claude/settings.local.json` allows
# `Bash(ruby -rjson -e:*)` as a wildcard but does not allow
# `python3`. Every ad-hoc `python3 -c …` therefore requires an
# explicit user permission prompt. Doing the same work in Ruby
# (which Phlex / Rails / the team already lives in) skips the
# prompt entirely.
#
# Block message tells the assistant to rewrite with `ruby -rjson -e`.
set -euo pipefail

INPUT="$(cat)"
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"

# `\bpython3?\b` — match `python` or `python3` as a whole word so
# names like `mypython` or `python2-config` don't trip it. Common
# call shapes: `python3 -c "..."`, `python3 <<EOF`, `python3 script.py`.
# All of those start with `python` / `python3` as a whole word
# somewhere in the command.
if printf '%s' "$COMMAND" | grep -qE '(^|[^A-Za-z0-9_])python3?($|[^A-Za-z0-9_])'; then
  cat >&2 <<'EOF'
🚫 Write Ruby, not Python.

The project's permission settings allowlist `ruby -rjson -e …`
(via the `.claude/settings.local.json` wildcard) but not Python.
Each Python `-c` invocation therefore requires an explicit
permission prompt, while the equivalent Ruby one-liner runs
through without one. For JSON parsing / data munging the two are
interchangeable — Ruby is just the friction-free path.

Rewrite the one-liner in Ruby and retry. If you genuinely need
Python (NumPy / scientific libs, etc.), ask the user to allowlist
the specific command before retrying.
EOF
  exit 2
fi

exit 0

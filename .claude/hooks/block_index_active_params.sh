#!/usr/bin/env bash
# Claude Code PreToolUse hook — fires for Bash (git commit) and
# Edit/Write/MultiEdit (save). Blocks adding new index_active_params
# methods or new shortcut symbols to existing ones in controllers.
#
# index_active_params is deprecated — see .claude/rules/index_active_params.md
# and GitHub issue #4636.
#
# Two modes:
#   Bash + git commit → scan staged additions in app/controllers/
#   Edit/Write        → scan new_string/content for controller files
set -euo pipefail

# Skip during merge commits — staged files include upstream content we don't own.
[ -f .git/MERGE_HEAD ] && exit 0

INPUT="$(cat)"
TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')"

CONTENT=""

case "$TOOL" in
  Bash)
    COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"
    case "$COMMAND" in
      *"git commit"*) ;;
      *) exit 0 ;;
    esac
    CONTENT="$(git diff --cached -U0 \
      -- 'app/controllers/*.rb' 'app/controllers/**/*.rb' \
      | grep '^+[^+]' | sed 's/^+//' \
      || true)"
    ;;

  Edit|Write)
    FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""')"
    case "$FILE" in
      */app/controllers/*.rb|*/app/controllers/**/*.rb) ;;
      *) exit 0 ;;
    esac
    case "$TOOL" in
      Edit)  CONTENT="$(printf '%s' "$INPUT" | jq -r '.tool_input.new_string // ""')" ;;
      Write) CONTENT="$(printf '%s' "$INPUT" | jq -r '.tool_input.content // ""')" ;;
    esac
    ;;

  MultiEdit)
    FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""')"
    case "$FILE" in
      */app/controllers/*.rb|*/app/controllers/**/*.rb) ;;
      *) exit 0 ;;
    esac
    CONTENT="$(printf '%s' "$INPUT" \
      | jq -r '[.tool_input.edits[].new_string] | join("\n")' 2>/dev/null \
      || true)"
    ;;

  *) exit 0 ;;
esac

[ -z "$CONTENT" ] && exit 0

# Detect: new def index_active_params, OR new symbols being spliced into
# an existing index_active_params array.  The second pattern looks for
# a bare :symbol_name inside what would be that method's array body —
# the surrounding `def`/`freeze` heuristic keeps false-positive rate low.
if printf '%s\n' "$CONTENT" | grep -qE '^\s*def index_active_params|index_active_params'; then
  cat >&2 <<'EOF'
⚠️  index_active_params is deprecated (issue #4636).

Every entry is a legacy shortcut URL alias (?project=123, ?by_user=456,
etc.) for something the Query system already handles natively via stable
?q[...] params. We are removing all of these, not adding more.

If you are building a filtered-index URL, use the Query system instead:

  # In a controller:
  query = Query.lookup(:Observation, projects: [@project])
  redirect_with_query(observations_path, query)

  # In a view/helper:
  link_to("Results", add_q_param(observations_path, query))

The resulting ?q[model]=Observation&q[projects][]=123 URL is fully
self-contained — no session or DB lookup needed. See:
  .claude/rules/index_active_params.md
EOF
fi

exit 0

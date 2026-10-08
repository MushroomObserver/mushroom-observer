#!/usr/bin/env bash
# Claude Code PostToolUse hook. Fires after Edit/Write/MultiEdit.
# Reads the saved file from disk and blocks if it contains a run of
# more than MAX_LINES consecutive comment lines anywhere -- not just
# in what this edit touched. Personal style rule (terse comments),
# corrected repeatedly across sessions. See .claude/rules/code_comments.md.
set -euo pipefail

MAX_LINES=5

INPUT="$(cat)"
TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')"

case "$TOOL" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""')"
case "$FILE" in
  .claude/*|*/.claude/*) exit 0 ;;
  *.rb|*.rake|*.scss) COMMENT_RE='^[[:space:]]*#' ;;
  *.js) COMMENT_RE='^[[:space:]]*//' ;;
  *) exit 0 ;;
esac

[ -f "$FILE" ] || exit 0

RUN=0
MAX_RUN=0
BLOCK=""
MAX_BLOCK=""
START_LINE=0
MAX_START_LINE=0
LINE_NO=0
while IFS= read -r line; do
  LINE_NO=$((LINE_NO + 1))
  if printf '%s' "$line" | grep -qE "$COMMENT_RE"; then
    [ "$RUN" -eq 0 ] && START_LINE=$LINE_NO
    RUN=$((RUN + 1))
    BLOCK="$BLOCK
$line"
  else
    if [ "$RUN" -gt "$MAX_RUN" ]; then
      MAX_RUN=$RUN
      MAX_BLOCK="$BLOCK"
      MAX_START_LINE=$START_LINE
    fi
    RUN=0
    BLOCK=""
  fi
done < "$FILE"
if [ "$RUN" -gt "$MAX_RUN" ]; then
  MAX_RUN=$RUN
  MAX_BLOCK="$BLOCK"
  MAX_START_LINE=$START_LINE
fi

if [ "$MAX_RUN" -gt "$MAX_LINES" ]; then
  cat >&2 <<EOF
🚫 BLOCKED: $FILE has a comment block of $MAX_RUN consecutive lines
(max $MAX_LINES), starting at line $MAX_START_LINE.

$MAX_BLOCK

Cut to the single load-bearing fact. Narrative belongs in the commit
message or PR description, not the comment. Applies even if this
edit didn't introduce that block -- fix it while the file's open.
EOF
  exit 2
fi

exit 0

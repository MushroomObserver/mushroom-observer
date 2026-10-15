#!/usr/bin/env bash
# Claude Code PostToolUse hook. Fires after Edit/Write/MultiEdit.
# Reads the saved file from disk and blocks if it contains a run of
# more than MAX_LINES consecutive comment lines anywhere -- not just
# in what this edit touched. Personal style rule (terse comments),
# corrected repeatedly across sessions. See .claude/rules/code_comments.md.
# Exempt: a comment block sitting directly above a class/module
# declaration (a docstring) -- same exemption the real
# MO/NoLongCommentBlock RuboCop cop grants.
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

CLASS_RE='^[[:space:]]*(class|module)[[:space:]]'

mapfile -t LINES < "$FILE"
TOTAL=${#LINES[@]}

RUN=0
START_LINE=0
VIOLATION_RUN=0
VIOLATION_START=0
VIOLATION_END=0

i=0
while [ "$i" -lt "$TOTAL" ]; do
  line="${LINES[$i]}"
  if printf '%s' "$line" | grep -qE "$COMMENT_RE"; then
    [ "$RUN" -eq 0 ] && START_LINE=$((i + 1))
    RUN=$((RUN + 1))
  else
    if [ "$RUN" -gt "$MAX_LINES" ] &&
       ! printf '%s' "$line" | grep -qE "$CLASS_RE"; then
      VIOLATION_RUN=$RUN
      VIOLATION_START=$START_LINE
      VIOLATION_END=$i
      break
    fi
    RUN=0
  fi
  i=$((i + 1))
done

# A long comment block that runs to the end of the file (nothing
# after it to exempt against) is never a docstring.
if [ "$VIOLATION_RUN" -eq 0 ] && [ "$RUN" -gt "$MAX_LINES" ]; then
  VIOLATION_RUN=$RUN
  VIOLATION_START=$START_LINE
  VIOLATION_END=$TOTAL
fi

if [ "$VIOLATION_RUN" -gt 0 ]; then
  BLOCK=$(sed -n "${VIOLATION_START},${VIOLATION_END}p" "$FILE")
  cat >&2 <<EOF
🚫 BLOCKED: $FILE has a comment block of $VIOLATION_RUN consecutive lines
(max $MAX_LINES), starting at line $VIOLATION_START.

$BLOCK

Cut to the single load-bearing fact. Narrative belongs in the commit
message or PR description, not the comment. Applies even if this
edit didn't introduce that block -- fix it while the file's open.
EOF
  exit 2
fi

exit 0

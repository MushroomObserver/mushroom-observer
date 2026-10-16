#!/usr/bin/env bash
# Claude Code PostToolUse hook. Fires after Edit/Write/MultiEdit.
# Reads the saved file from disk and blocks if it contains a run of
# more than MAX_LINES consecutive comment lines anywhere -- not just
# in what this edit touched. Personal style rule (terse comments),
# corrected repeatedly across sessions. See .claude/rules/code_comments.md.
# Mirrors the real MO/NoLongCommentBlock cop
# (lib/rubocop/cop/mo/no_long_comment_block.rb + its Max: 10 in
# .rubocop.yml), kept in sync by hand:
# - a run directly above a class/module declaration (a docstring)
# - a run that's mostly YARD tags / RDoc-style reference markup
#   (not narrative prose)
# - a run wrapped in its own rubocop:disable/:enable pair for this
#   cop (or `all`) -- RuboCop's engine honors that regardless of what
#   the cop itself checks, so the hook must too
set -euo pipefail

MAX_LINES=10

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

# Same reference-line shapes as the cop's REFERENCE_LINE regex: a YARD
# tag, an RDoc `term::` entry, a `term - description` entry, an
# `== Heading`, a `:section:` marker, a `#`/`=` divider line, or an
# indented (3+ space) continuation line.
REFERENCE_RE='^#([[:space:]]*@[A-Za-z_][A-Za-z0-9_]*'
REFERENCE_RE+='|[[:space:]]*[^[:space:]]+::([[:space:]]|$)'
REFERENCE_RE+='|[[:space:]]*:?[A-Za-z0-9_]+[[:space:]]+-[[:space:]]+[^[:space:]]'
REFERENCE_RE+='|[[:space:]]*={2,}[[:space:]]'
REFERENCE_RE+='|[[:space:]]*:section:'
REFERENCE_RE+='|[[:space:]]*[#=]{3,}[[:space:]]*$'
REFERENCE_RE+='|[[:space:]]{3,}[^[:space:]])'

mapfile -t LINES < "$FILE"
TOTAL=${#LINES[@]}

# True if lines [start,end] (1-based, inclusive) sit directly above a
# class/module keyword, allowing one blank separator line.
is_class_or_module_doc() {
  local end=$1
  local next="${LINES[$end]:-}"
  if [ -z "${next//[[:space:]]/}" ]; then
    next="${LINES[$((end + 1))]:-}"
  fi
  printf '%s' "$next" | grep -qE "$CLASS_RE"
}

# True if >=75% of a run's non-blank comment lines read as structured
# reference markup rather than narrative prose.
is_reference_run() {
  local start=$1 end=$2
  local total=0 matches=0 j stripped
  for ((j = start; j <= end; j++)); do
    stripped="$(printf '%s' "${LINES[$((j - 1))]}" | sed -E 's/^[[:space:]]*//')"
    [ "$stripped" = "#" ] && continue
    total=$((total + 1))
    printf '%s' "$stripped" | grep -qE "$REFERENCE_RE" && matches=$((matches + 1))
  done
  [ "$total" -gt 0 ] && [ $((matches * 4)) -ge $((total * 3)) ]
}

DISABLE_RE='rubocop:disable[[:space:]]+(MO/NoLongCommentBlock|all)\b'
ENABLE_RE='rubocop:enable[[:space:]]+(MO/NoLongCommentBlock|all)\b'

# True if the run contains its own disable ... enable pair for this
# cop -- a prior deliberate exemption, not an oversight.
is_disabled_run() {
  local start=$1 end=$2
  local j has_disable=0 has_enable=0
  for ((j = start; j <= end; j++)); do
    local l="${LINES[$((j - 1))]}"
    printf '%s' "$l" | grep -qE "$DISABLE_RE" && has_disable=1
    printf '%s' "$l" | grep -qE "$ENABLE_RE" && has_enable=1
  done
  [ "$has_disable" -eq 1 ] && [ "$has_enable" -eq 1 ]
}

VIOLATION_RUN=0
VIOLATION_START=0
VIOLATION_END=0

RUN=0
START_LINE=0
i=0
while [ "$i" -le "$TOTAL" ]; do
  line="${LINES[$i]:-}"
  if [ "$i" -lt "$TOTAL" ] && printf '%s' "$line" | grep -qE "$COMMENT_RE"; then
    [ "$RUN" -eq 0 ] && START_LINE=$((i + 1))
    RUN=$((RUN + 1))
    i=$((i + 1))
    continue
  fi

  if [ "$RUN" -gt "$MAX_LINES" ]; then
    end=$((START_LINE + RUN - 1))
    if ! is_class_or_module_doc "$end" && ! is_reference_run "$START_LINE" "$end" &&
       ! is_disabled_run "$START_LINE" "$end"; then
      VIOLATION_RUN=$RUN
      VIOLATION_START=$START_LINE
      VIOLATION_END=$end
      break
    fi
  fi
  RUN=0
  i=$((i + 1))
done

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

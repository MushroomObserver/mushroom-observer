#!/usr/bin/env bash
# Claude Code PostToolUse hook. Fires after Edit/Write/MultiEdit.
# Blocks a run of more than MAX_LINES consecutive comment lines
# anywhere in the saved file, not just what this edit touched.
# Mirrors MO/NoLongCommentBlock (lib/rubocop/cop/mo/no_long_comment_block.rb,
# Max: 10 in .rubocop.yml): exempts class/module docstrings, YARD/RDoc
# reference runs, and rubocop:disable/:enable-wrapped runs, like that
# cop does. See .claude/rules/code_comments.md.
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
  .claude/local/*|*/.claude/local/*) exit 0 ;;
  *.rb|*.rake|*.scss|*.sh) COMMENT_RE='^[[:space:]]*#' ;;
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

# True if the run overlaps a disable/enable region for this cop -- a prior
# deliberate exemption, not an oversight.
# RuboCop suppresses an offense whose range overlaps an active
# disable/enable region at all -- not just a region fully containing
# the run, and not just the run's start or end line in isolation. A
# leading heading line before the disable marker, or trailing lines
# after the enable marker, can still be part of one suppressed run as
# long as SOME line in [start,end] falls inside the disabled region.
# Scan from the top of the file, tracking disable/enable as a toggle,
# and flag an overlap whenever the toggle is active at or after start.
is_disabled_run() {
  local start=$1 end=$2
  local j disabled=0 overlapped=0
  for ((j = 1; j <= end; j++)); do
    local l="${LINES[$((j - 1))]}"
    printf '%s' "$l" | grep -qE "$DISABLE_RE" && disabled=1
    if [ "$disabled" -eq 1 ] && [ "$j" -ge "$start" ]; then
      overlapped=1
    fi
    printf '%s' "$l" | grep -qE "$ENABLE_RE" && disabled=0
  done
  [ "$overlapped" -eq 1 ]
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

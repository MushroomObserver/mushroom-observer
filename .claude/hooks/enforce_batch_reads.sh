#!/usr/bin/env bash
# Claude Code PreToolUse hook — fires before every Read tool call.
#
# Enforces two batch-read discipline rules:
#
# 1. Re-read handling:
#    - In a parallel batch (gap ≤ 3s since last Read): if the file
#      was already read, silently allow it — it is in context alongside
#      the other files in the batch and the re-read is an accident, not
#      a pattern.
#    - As a solo read (gap > 3s): if the file was already read ON THE
#      SAME BRANCH, BLOCK with an explanation. Solo re-reads across
#      separate messages mean Claude is reading files one at a time
#      instead of batching.
#    - Branch switch: if the file was read on a different branch,
#      allow the re-read (the on-disk content may have changed).
#
# 2. WARN on previous solo-read batch: if the previous group of Read
#    calls contained only ONE new file, warn at the start of the next
#    group. Nudges issuing all needed Read calls in a single parallel
#    message.
#
# State files (under /tmp — cleared on session start via SessionStart hook):
#   /tmp/claude_reads.txt         — "BRANCH\tPATH" per line
#   /tmp/claude_read_batch_ts     — epoch seconds of the most-recent Read call
#   /tmp/claude_read_batch_count  — new-file reads in the current batch
#
set -euo pipefail

INPUT="$(cat)"
FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""')"
[ -z "$FILE" ] && exit 0

READS_FILE="/tmp/claude_reads.txt"
BATCH_TS_FILE="/tmp/claude_read_batch_ts"
BATCH_COUNT_FILE="/tmp/claude_read_batch_count"

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "__nobranch__")"

# Timing first — needed for both re-read and solo-read logic
NOW=$(date +%s)
LAST_TS=$(cat "$BATCH_TS_FILE" 2>/dev/null || echo 0)
PREV_COUNT=$(cat "$BATCH_COUNT_FILE" 2>/dev/null || echo 0)
GAP=$((NOW - LAST_TS))

# ── 1. Re-read handling ────────────────────────────────────────────
# Check if this file appears in the reads log at all
if awk -F'\t' -v f="$FILE" '$2 == f {found=1; exit} END {exit !found}' \
     "$READS_FILE" 2>/dev/null; then
  if [ "$GAP" -le 3 ]; then
    # Same parallel batch — file is in context, silently proceed
    exit 0
  fi

  # Check whether it was read on the current branch
  if grep -qxF "${BRANCH}	${FILE}" "$READS_FILE" 2>/dev/null; then
    # Same branch — solo re-read across messages: block
    cat >&2 <<EOF
🚫 RE-READ BLOCKED: $FILE

This file was already read this session and its content is in
context. Solo re-reads across separate messages mean files are
being read one at a time rather than batched upfront.

Fix: issue ALL Read calls for a task in a single parallel message
BEFORE making any edits. Re-reads in a parallel batch (multiple
files at once) are silently allowed; only solo re-reads are blocked.

The Edit tool confirms "file state is current in context" after
every edit — recently-edited files also do not need a re-read.

Bypass (context-compression only): if the session was compressed
and file content was genuinely dropped, ask the user to run:
  rm /tmp/claude_reads.txt
EOF
    exit 2
  else
    # Different branch — file content may have changed, allow
    # Remove the stale entry so it gets re-recorded below under the new branch
    awk -F'\t' -v f="$FILE" '$2 != f' "$READS_FILE" \
      > "${READS_FILE}.tmp" && mv "${READS_FILE}.tmp" "$READS_FILE" || true
  fi
fi

# ── Record new file + update batch tracking ────────────────────────
echo "${BRANCH}	${FILE}" >> "$READS_FILE"

if [ "$GAP" -gt 3 ]; then
  # New batch starting — warn if previous batch was a solo read
  if [ "$PREV_COUNT" -eq 1 ]; then
    jq -n '{
      "systemMessage": "BATCH READS: previous message had only 1 Read call. Issue ALL Read calls for a task in a single parallel message — not one file at a time. Solo re-reads are blocked, so forgetting a file means the user must intervene."
    }'
  fi
  echo "1" > "$BATCH_COUNT_FILE"
else
  echo $((PREV_COUNT + 1)) > "$BATCH_COUNT_FILE"
fi

echo "$NOW" > "$BATCH_TS_FILE"

exit 0

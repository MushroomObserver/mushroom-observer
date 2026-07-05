#!/usr/bin/env bash
# Claude Code PreToolUse hook — fires before every Read tool call.
#
# Enforces two batch-read discipline rules:
#
# 1. Re-read handling:
#    - mtime check first: if the file's on-disk mtime differs from
#      what was recorded at last-read time, the file genuinely
#      changed since (a PostToolUse formatter hook like rubocop
#      autocorrect rewriting it after a Write/Edit, the user editing
#      it, a branch switch, etc.) — drop the stale record and allow
#      the read unconditionally. The block below only ever applies to
#      a truly-unchanged file.
#    - In a parallel batch (gap ≤ 3s since last Read): if the file
#      was already read, silently allow it — it is in context alongside
#      the other files in the batch and the re-read is an accident, not
#      a pattern.
#    - As a solo read (gap > 3s): if the file was already read ON THE
#      SAME BRANCH and is unchanged, BLOCK with an explanation. Solo
#      re-reads across separate messages mean Claude is reading files
#      one at a time instead of batching.
#    - Branch switch (unchanged file): if the file was read on a
#      different branch, allow the re-read (the checked-out content
#      may differ from what was in context).
#
# 2. WARN on previous solo-read batch: if the previous group of Read
#    calls contained only ONE new file, warn at the start of the next
#    group. Nudges issuing all needed Read calls in a single parallel
#    message.
#
# State files (under /tmp — cleared on session start via SessionStart hook):
#   /tmp/claude_reads.txt         — "BRANCH\tPATH\tMTIME" per line
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

# BSD stat (macOS) first, GNU stat fallback (Linux/CI).
get_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}
CURRENT_MTIME="$(get_mtime "$FILE")"

# Timing first — needed for both re-read and solo-read logic
NOW=$(date +%s)
LAST_TS=$(cat "$BATCH_TS_FILE" 2>/dev/null || echo 0)
PREV_COUNT=$(cat "$BATCH_COUNT_FILE" 2>/dev/null || echo 0)
GAP=$((NOW - LAST_TS))

# ── 1. Re-read handling ────────────────────────────────────────────
# At most one record per file path is kept (every branch below either
# leaves the record alone or strips it before re-adding), so the
# first match is the only match.
EXISTING="$(awk -F'\t' -v f="$FILE" '$2 == f {print; exit}' "$READS_FILE" 2>/dev/null || true)"

if [ -n "$EXISTING" ]; then
  REC_BRANCH="$(printf '%s' "$EXISTING" | cut -f1)"
  REC_MTIME="$(printf '%s' "$EXISTING" | cut -f3)"

  if [ "$REC_MTIME" != "$CURRENT_MTIME" ]; then
    # Changed on disk since last read — a formatter hook, our own
    # edit, or the user touched it. The staleness the block exists to
    # prevent doesn't apply; drop the old record so it re-records
    # below with the current mtime.
    awk -F'\t' -v f="$FILE" '$2 != f' "$READS_FILE" \
      > "${READS_FILE}.tmp" && mv "${READS_FILE}.tmp" "$READS_FILE" || true
  elif [ "$GAP" -le 3 ]; then
    # Same parallel batch — file is in context, silently proceed
    exit 0
  elif [ "$REC_BRANCH" = "$BRANCH" ]; then
    # Same branch, unchanged file, solo re-read across messages: block
    cat >&2 <<EOF
🚫 RE-READ BLOCKED: $FILE

This file was already read this session and its content is in
context (unchanged on disk since). Solo re-reads across separate
messages mean files are being read one at a time rather than
batched upfront.

Fix: issue ALL Read calls for a task in a single parallel message
BEFORE making any edits. Re-reads in a parallel batch (multiple
files at once) are silently allowed; only solo re-reads of an
UNCHANGED file are blocked.

The Edit tool confirms "file state is current in context" after
every edit — recently-edited files also do not need a re-read.

Bypass (context-compression only): if the session was compressed
and file content was genuinely dropped, ask the user to run:
  rm /tmp/claude_reads.txt
EOF
    exit 2
  else
    # Different branch, unchanged file — the checked-out content may
    # differ from what was in context; allow. Remove the stale entry
    # so it gets re-recorded below under the new branch.
    awk -F'\t' -v f="$FILE" '$2 != f' "$READS_FILE" \
      > "${READS_FILE}.tmp" && mv "${READS_FILE}.tmp" "$READS_FILE" || true
  fi
fi

# ── Record new file + update batch tracking ────────────────────────
echo "${BRANCH}	${FILE}	${CURRENT_MTIME}" >> "$READS_FILE"

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

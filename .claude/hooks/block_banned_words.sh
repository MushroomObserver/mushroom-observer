#!/usr/bin/env bash
# Claude Code PreToolUse hook.
# Fires before Edit/Write/MultiEdit (file content) and before Bash
# calls that create/edit a git commit or a GitHub issue/PR/comment
# (git commit -m, gh issue/pr create|edit|comment|review, gh api
# ...body=, and any --body-file content). Blocks the action if the
# new text contains one of the user's banned intensifier/hedge words.
#
# Why: personal style rules, corrected multiple times in conversation
# and previously tracked only as memory (which the assistant has to
# recall and apply itself, and can miss). See
# .claude/rules/gh_pr_bodies.md's no-hyperbole section and project
# memory feedback_banned_words_real_genuine.md /
# feedback_banned_words_canonical_consume.md /
# feedback_never_is_a_narrative_smell.md.
#
# Word list: real, genuine(ly), actual(ly), exactly, never, ever,
# canonical, consume, "at all" -- used as intensifiers/hedges, they
# carry no information and read as arguing for a claim instead of
# just stating it. Whole-word matches only (so e.g. "actualization",
# "eventual" don't false-positive); case-insensitive.
#
# Blunt by design, same philosophy as block_pii_in_gh.sh: false
# positives get fixed by rephrasing, not by bypassing the hook.
set -euo pipefail

INPUT="$(cat)"
TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')"

WORD_RE='\b(real|genuine(ly)?|actual(ly)?|exactly|never|ever|canonical|consume)\b|at all'

TEXT=""
case "$TOOL" in
  Edit|Write|MultiEdit)
    FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""')"
    # Only source files -- not every Write (e.g. scratch/log files
    # outside the repo) needs this scrutiny.
    case "$FILE" in
      .claude/*|*/.claude/*) exit 0 ;;
      *.rb|*.rake|*.erb|*.scss|*.md) ;;
      *) exit 0 ;;
    esac
    TEXT="$(printf '%s' "$INPUT" | jq -r '
      (.tool_input.content // "") + "\n" +
      (.tool_input.new_string // "") + "\n" +
      ((.tool_input.edits // []) | map(.new_string // "") | join("\n"))
    ')"
    ;;
  Bash)
    COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"
    if ! printf '%s' "$COMMAND" | grep -qE \
      'git[[:space:]]+commit|gh[[:space:]]+(issue|pr)[[:space:]]+(create|edit|comment|review)|gh[[:space:]]+api[[:space:]].*body='; then
      exit 0
    fi
    TEXT="$COMMAND"
    FILES="$(printf '%s' "$COMMAND" \
      | grep -oE -- '--body-file[[:space:]=]+[^[:space:]]+' \
      | sed -E 's/^--body-file[[:space:]=]+//' | tr -d "\"'" || true)"
    for f in $FILES; do
      [ -f "$f" ] && TEXT="$TEXT
$(cat "$f")"
    done
    ;;
  *) exit 0 ;;
esac

# Strip comment lines discussing the rule itself (e.g. this file, or
# a rules doc quoting the banned words) -- only match live prose/code.
HITS="$(printf '%s' "$TEXT" | grep -inE "$WORD_RE" || true)"

if [ -n "$HITS" ]; then
  cat >&2 <<EOF
🚫 BLOCKED: banned word/phrase detected (real/genuine/actual(ly)/
exactly/never/ever/canonical/consume/"at all" used as an intensifier
or hedge -- personal style ban, corrected multiple times).

Matches:
$HITS

Cut the word outright rather than substituting a synonym (truly,
legitimately, literally have the same problem). State the plain fact
instead. If this is a direct quote discussing the rule itself, ask
the user before proceeding.
EOF
  exit 2
fi

exit 0

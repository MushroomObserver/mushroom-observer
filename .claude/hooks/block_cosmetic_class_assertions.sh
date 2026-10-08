#!/usr/bin/env bash
# Claude Code PreToolUse hook.
# Fires before Edit/Write/MultiEdit on `test/**/*_test.rb`. Blocks a
# save when an `assert_html`/`assert_no_html`/`assert_selector`/
# `assert_not_includes`/`assert_includes` call's argument string pins
# a cosmetic Bootstrap class -- button chrome (`.btn`, `.btn-default`,
# `.btn-outline-*`, `.btn-sm/-lg/-xs`), spacing utilities (`.mt-3`,
# `.px-2`, `.m-0`, `.ml-auto`, `.mx-n2`, etc.), or known paint classes
# (`.font-weight-*`, `.text-muted`).
#
# Why this exists as a hook, not just a memory/rule doc: this exact
# anti-pattern (previously documented in project memory
# feedback_no_cosmetic_classes_in_component_tests.md) recurred more
# than once in the same session even after being corrected earlier in
# that session, including re-writing the class name mid-fix while
# removing a neighboring instance of the same pattern. Self-policing
# via remembered rules has failed repeatedly; this is the mechanical
# backstop. See .claude/rules/testing.md ("Don't pin cosmetic CSS
# classes") for the full rule and its carve-outs.
#
# Deliberately blunt, same philosophy as block_banned_words.sh: a
# false positive (a styling-abstraction component's test asserting
# its OWN class-output contract, e.g. Panel/Modal/CrudButton/Well) is
# fixed by asking the user to confirm the exception applies, not by
# silently bypassing the hook.
set -euo pipefail

INPUT="$(cat)"
TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')"
case "$TOOL" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""')"
case "$FILE" in
  test/*_test.rb) ;;
  *) exit 0 ;;
esac

NEW="$(printf '%s' "$INPUT" | jq -r '
  (.tool_input.content // "") + "\n" +
  (.tool_input.new_string // "") + "\n" +
  ((.tool_input.edits // []) | map(.new_string // "") | join("\n"))
')"

# Only look at assertion-call lines -- a test file's setup code,
# comments, or a component's own `class:` string elsewhere aren't
# what this hook is about.
ASSERT_LINES="$(printf '%s' "$NEW" | grep -inE \
  'assert_(html|no_html|selector|not_includes|includes)\(' || true)"

[ -z "$ASSERT_LINES" ] && exit 0

# Cosmetic-class patterns: Bootstrap button chrome, spacing utilities
# (m/p + optional t/b/l/r/x/y + a numeric step, `auto`, or a negative
# `n<N>` margin step -- covers both margin and padding symmetrically),
# and a couple of known paint classes. Matched as a CSS class token
# (preceded by `.`) so it doesn't false-hit unrelated words.
PATTERN='\.btn(-[a-z]+)?\b|\.[mp][tblrxy]?-(n?[0-9]+|auto)\b|\.font-weight-[a-z]+\b|\.text-muted\b'

HITS="$(printf '%s' "$ASSERT_LINES" | grep -inE "$PATTERN" || true)"

if [ -n "$HITS" ]; then
  cat >&2 <<EOF
🚫 BLOCKED: cosmetic Bootstrap class asserted in a test
($FILE).

Matches:
$HITS

Component tests assert behavior/contract, not paint -- see
.claude/rules/testing.md ("Don't pin cosmetic CSS classes"). Common
fixes:
  - Drop the class from the selector; assert the semantic class,
    data-*/aria-* attr, or visible text instead.
  - If the class is genuinely part of a "styling-abstraction"
    component's own contract (Panel/Modal/CrudButton/Well -- where
    the class output IS the thing under test), that's a real
    exception -- confirm with the user before keeping it, and say
    why in this response.
  - "It's inside a conditional in the code" is NOT by itself a
    reason to keep it -- test the semantic branch marker (e.g. an
    arrow-up/arrow-down class), not the specific spacing utility the
    conditional happens to toggle.
EOF
  exit 2
fi

exit 0

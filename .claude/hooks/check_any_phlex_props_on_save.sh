#!/usr/bin/env bash
# Claude Code PreToolUse hook.
# Fires before `Edit` / `Write` / `MultiEdit` Bash calls. If the
# tool is writing to a Ruby file under `app/components/` or
# `app/views/`, block the write when the new content contains
# either:
#
#   - a bare `_Any` prop declaration (antipattern documented in
#     `.claude/rules/phlex_conversions.md` and enforced post-hoc by
#     `test/style/no_any_phlex_props_test.rb`), or
#   - `.html_safe` / `raw(...)` (Phlex views should use the
#     buffer-writing `trusted_html(...)` helper instead — see the
#     phlex-conversions rule + matching style guidance).
#
# Catches both antipatterns before the file lands on disk.
#
# Allows `_Any` / `raw` / `html_safe` outside `app/components/` and
# `app/views/` — controllers, models, helpers, tests are unaffected.
set -euo pipefail

INPUT="$(cat)"
TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')"
case "$TOOL" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""')"
case "$FILE" in
  *app/components/*.rb|*app/views/*.rb) ;;
  *) exit 0 ;;
esac

# For Edit / MultiEdit: check `new_string` (Edit) and each
# `edits[].new_string` (MultiEdit). For Write: check `content`.
NEW="$(printf '%s' "$INPUT" | jq -r '
  (.tool_input.content // "") + "\n" +
  (.tool_input.new_string // "") + "\n" +
  ((.tool_invocation.edits // .tool_input.edits // []) | map(.new_string // "") | join("\n"))
')"

# Strip comment-only lines before pattern matching — discussion /
# removal-notes that mention these antipatterns shouldn't trip the
# guard. (`grep -v '^\s*#'` after `grep -n` keeps line numbers.)

# 1. Bare `_Any` (word boundary on both sides), not a substring of
#    something larger like `_AnyThing`.
ANY_OFFENDERS="$(printf '%s\n' "$NEW" | grep -nE '(\s|^)_Any\b' | grep -v '^[0-9]*:\s*#' || true)"

# 2. `.html_safe` (chained on any expression) or `raw(...)`. Phlex
#    views should use `trusted_html(...)`, which writes safely-
#    marked content to the buffer.
RAW_OFFENDERS="$(printf '%s\n' "$NEW" | grep -nE '\.html_safe\b|(\s|^|\()raw\(' | grep -v '^[0-9]*:\s*#' || true)"

if [ -n "$ANY_OFFENDERS" ]; then
  cat >&2 <<EOF
🚫 \`_Any\` prop declaration in a Phlex view/component file —
blocking write.

File: $FILE
Offending lines:
$ANY_OFFENDERS

Per \`.claude/rules/phlex_conversions.md\`: use a concrete prop
type instead of \`_Any\` so caller mistakes fail at construction
(\`Literal::TypeError\`) rather than later inside \`view_template\`.

\`_Any\` is only OK when the arg genuinely can be any type AND the
view has explicit polymorphic handling (case-by-class) — rare. If
you think this is one of those cases, ask the user before saving.
EOF
  exit 2
fi

if [ -n "$RAW_OFFENDERS" ]; then
  cat >&2 <<EOF
🚫 \`.html_safe\` / \`raw(...)\` in a Phlex view/component file —
blocking write.

File: $FILE
Offending lines:
$RAW_OFFENDERS

Phlex views write to the output buffer; for already-safe content
(translation strings, textile-rendered HTML, etc.) use the
buffer-writing \`trusted_html(...)\` helper instead. When you need
a captured value to remain html_safe for interpolation, use
\`capture { ... }\` — its return value is already an
\`ActiveSupport::SafeBuffer\`.
EOF
  exit 2
fi

exit 0

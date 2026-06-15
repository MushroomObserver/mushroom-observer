#!/usr/bin/env bash
# Claude Code PreToolUse hook.
# Fires before `Edit` / `Write` / `MultiEdit` Bash calls. If the
# tool is writing to a Ruby file under `app/components/` or
# `app/views/`, block the write when the new content contains
# any of:
#
#   - a bare `_Any` prop declaration (antipattern documented in
#     `.claude/rules/phlex_conversions.md` and enforced post-hoc by
#     `test/style/no_any_phlex_props_test.rb`), or
#   - `.html_safe` / `raw(...)` (Phlex views should use the
#     buffer-writing `trusted_html(...)` helper instead — see the
#     phlex-conversions rule + matching style guidance), or
#   - `view_context.foo` (silent ActionView dispatch — same family
#     as `helpers.foo`, banned by
#     `test/style/no_helpers_in_phlex_views_test.rb`).
#
# Catches each antipattern before the file lands on disk.
#
# Allows the patterns outside `app/components/` and `app/views/` —
# controllers, models, helpers, tests are unaffected.
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
# guard. POSIX ERE doesn't reliably support `\b` / `\s` / `\w`
# (macOS / BSD greps may treat them as literals, not metacharacters);
# use `[[:space:]]` / `[^[:alnum:]_]` instead so the regexes work on
# any conformant grep.
COMMENT_LINE_RE='^[0-9]*:[[:space:]]*#'

# 1. Bare `_Any` — non-word boundary (or start-of-line) before AND
#    non-word boundary (or end-of-line) after. Covers `, _Any` AND
#    `,_Any` (no space) AND `(_Any` etc., without matching
#    identifiers like `_AnyThing` or `Foo_Any`.
ANY_OFFENDERS="$(printf '%s\n' "$NEW" | grep -nE '(^|[^[:alnum:]_])_Any([^[:alnum:]_]|$)' | grep -v "$COMMENT_LINE_RE" || true)"

# 2. `.html_safe` (chained on any expression) or `raw(...)`. Phlex
#    views should use `trusted_html(...)`, which writes safely-
#    marked content to the buffer.
RAW_OFFENDERS="$(printf '%s\n' "$NEW" | grep -nE '\.html_safe([^[:alnum:]_]|$)|(^|[[:space:]]|\()raw\(' | grep -v "$COMMENT_LINE_RE" || true)"

# 3. `view_context.foo` — same family as `helpers.foo` (silent
#    dispatch into the ActionView helper chain). Inline the logic
#    onto the Phlex view as a private method or register the
#    helper at the base-class level. When a Phlex tag needs to
#    return a SafeBuffer string for interpolation, use
#    `capture { a(href: …) { … } }` instead of `view_context.tag.a`.
#    Uses the same `(^|[^[:alnum:]_])` POSIX boundary as `_Any` —
#    `\b` isn't portable on BSD grep.
VIEW_CONTEXT_OFFENDERS="$(printf '%s\n' "$NEW" | grep -nE '(^|[^[:alnum:]_])view_context\.[A-Za-z_][A-Za-z0-9_]*[!?=]?' | grep -v "$COMMENT_LINE_RE" || true)"

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

if [ -n "$VIEW_CONTEXT_OFFENDERS" ]; then
  cat >&2 <<EOF
🚫 \`view_context.<method>\` in a Phlex view/component file —
blocking write.

File: $FILE
Offending lines:
$VIEW_CONTEXT_OFFENDERS

Same family as \`helpers.<method>\` — silent runtime dispatch into
ActionView, brittle across Phlex versions. Inline the logic onto
the Phlex view as a private method, register the helper at the
base-class level (\`register_value_helper\` / \`register_output_helper\`),
or call the underlying Phlex tag directly (\`a(href: …)\` instead of
\`view_context.tag.a(…)\`). When you need a returned SafeBuffer
string for interpolation, use \`capture { ... }\`.
EOF
  exit 2
fi

exit 0

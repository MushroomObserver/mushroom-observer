#!/usr/bin/env bash
# Claude Code PreToolUse hook.
# Fires before `Edit` / `Write` / `MultiEdit` Bash calls. If the
# tool is writing to a Ruby file under `app/components/` or
# `app/views/`, block the write when the new content contains a
# bare `_Any` prop declaration (the antipattern documented in
# `.claude/rules/phlex_conversions.md` and enforced post-hoc by
# `test/style/no_any_phlex_props_test.rb`).
#
# Catches it before the file lands on disk instead of after the
# style test fails on CI.
#
# Allows `_Any` outside the `app/components/` and `app/views/`
# trees (no Phlex view contract there).
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
  ((.tool_input.edits // []) | map(.new_string // "") | join("\n"))
')"

# Match bare `_Any` (word boundary on both sides), but not as a
# fragment of something larger (`_AnyThing`). Also skip lines that
# are comments — discussion / removal-notes about `_Any` shouldn't
# fire the guard.
OFFENDERS="$(printf '%s\n' "$NEW" | grep -nE '(\s|^)_Any\b' | grep -v '^\s*[0-9]*:\s*#' || true)"

if [ -n "$OFFENDERS" ]; then
  cat >&2 <<EOF
🚫 \`_Any\` prop declaration in a Phlex view/component file —
blocking write.

File: $FILE
Offending lines:
$OFFENDERS

Per \`.claude/rules/phlex_conversions.md\`: use a concrete prop
type instead of \`_Any\` so caller mistakes fail at construction
(\`Literal::TypeError\`) rather than later inside \`view_template\`.

\`_Any\` is only OK when the arg genuinely can be any type AND the
view has explicit polymorphic handling (case-by-class) — rare. If
you think this is one of those cases, ask the user before saving.
EOF
  exit 2
fi

exit 0

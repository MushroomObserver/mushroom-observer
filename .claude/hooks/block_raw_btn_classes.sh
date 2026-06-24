#!/usr/bin/env bash
# Claude Code PreToolUse hook.
# Fires before `Bash` calls. If the command is a `git commit`, scan
# staged additions in `app/components/` and `app/views/controllers/`
# for raw `btn` class strings passed directly to `link_to`, `button_to`,
# `a(`, or `button(`. Those callers should reach for a `Components::Button`
# subclass instead.
#
# Exempt from scanning:
#   * app/components/button.rb and app/components/button/**
#     (the Button hierarchy itself legitimately references btn classes)
#   * Comment lines  — # lines are skipped
#   * Test files     — test/ is not in scope
set -euo pipefail

INPUT="$(cat)"
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"

case "$COMMAND" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

# Collect staged-added lines from target paths.
# The Button hierarchy itself is excluded at the pathspec level so its
# legitimate btn references never enter the scan.
ADDED="$(git diff --cached -U0 \
  -- \
  'app/components/*.rb' \
  'app/components/**/*.rb' \
  'app/views/controllers/**/*.rb' \
  ':(exclude)app/components/button.rb' \
  ':(exclude)app/components/button/**' \
  | grep '^+[^+]' \
  | sed 's/^+//' \
  | grep -v '^[[:space:]]*#' \
  || true)"

[ -z "$ADDED" ] && exit 0

# Flag string literals that contain `btn` as a standalone class token:
# "btn", "btn-primary", "btn btn-default", "my-2 btn", etc.
BTN_PATTERN='["'"'"'][^"'"'"']*\bbtn\b[^"'"'"']*["'"'"']'

OFFENDERS="$(printf '%s\n' "$ADDED" | grep -En "$BTN_PATTERN" || true)"

[ -z "$OFFENDERS" ] && exit 0

# Narrow to lines that pass a class-bearing kwarg to a low-level HTML
# builder. This avoids false positives in string comparisons or comments.
RELEVANT="$(printf '%s\n' "$OFFENDERS" \
  | grep -E '(link_to|button_to|[^:]\ba\(|[^:]\bbutton\()' \
  || true)"

[ -z "$RELEVANT" ] && exit 0

cat >&2 <<'EOF'
🚫 Raw `btn` class string in a view or component — blocking commit.

`link_to`, `button_to`, `a(`, and `button(` calls in
`app/components/` and `app/views/controllers/` must NOT pass raw
Bootstrap btn class strings like `class: "btn btn-primary"`.

Reach for the appropriate `Components::Button` subclass instead:

  Edit / view      → Components::Button::Edit.new(target: …)
  Delete / destroy → Components::Button::Delete.new(target: …)
  POST action      → Components::Button::Post.new(name: …, target: …)
  PATCH/PUT action → Components::Button::Patch / Button::Put
  Plain GET link   → Components::Button::Get.new(name: …, target: …)
  Download link    → Components::Button::Download.new(target: …)
  Modal trigger    → Components::Button::ModalToggle.new(…, modal_id: …)
  External link    → Components::Button::External.new(url: …, name: …)
  Submit button    → Components::Button::Submit.new(name: …)

If you genuinely need a one-off btn style that no subclass covers,
pass `variant: :primary` (or the named variant) to the closest subclass
rather than hand-rolling the class string.

Offending lines:
EOF

printf '%s\n' "$RELEVANT" >&2

exit 2

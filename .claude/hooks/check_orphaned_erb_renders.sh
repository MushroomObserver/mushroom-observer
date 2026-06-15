#!/usr/bin/env bash
# Claude Code PreToolUse hook.
# Fires before `Bash` calls. If the command is a `git commit` and the
# staged change deletes one or more ERB action templates / partials,
# scan `app/` for any remaining `render(...)` call that referenced
# the deleted view by name — i.e. the classic ERB→Phlex footgun:
# delete `app/views/controllers/foo/show.html.erb`, forget that
# `Bar::Controller#update` somewhere does
# `render("foo/show", location: …)`, ship the PR, CI fails with
# `ActionView::MissingTemplate: Missing template foo/show`.
#
# What we flag (per deleted ERB at `app/views/controllers/<X>/<Y>.html.erb`):
#   * `render("<X>/<Y>")`
#   * `render('<X>/<Y>')`
#   * `render(:<Y>)` / `render(action: :<Y>)` / `render(action: "<Y>")`
#   * `render(template: "<X>/<Y>")`
#   * For partials (`_foo.html.erb`): `render(partial: "<X>/<foo>")`
#
# Filtered out: lines that already include `Views::Controllers::`
# (those are the explicit Phlex renders the conversion adds).
#
# Block message tells the assistant to swap the surviving string-/
# symbol-form `render(...)` calls to explicit Phlex renders.
set -euo pipefail

INPUT="$(cat)"
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"

# Only interested in git commit. Skip everything else.
case "$COMMAND" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

# Get staged-deleted ERB files under `app/views/`.
DELETED="$(git diff --cached --diff-filter=D --name-only \
  | grep -E '^app/views/.*\.erb$' || true)"
[ -z "$DELETED" ] && exit 0

OFFENDERS=""

while IFS= read -r erb; do
  [ -z "$erb" ] && continue

  # `app/views/controllers/foo/show.html.erb` → `foo/show`
  # `app/views/controllers/foo/_partial.html.erb` → `foo/_partial`
  rel="${erb#app/views/}"
  rel="${rel#controllers/}"
  rel="${rel%.html.erb}"
  rel="${rel%.erb}"

  base="$(basename "$rel")"
  dir="$(dirname "$rel")"

  matches=""

  if [[ "$base" == _* ]]; then
    # Partial — strip the leading underscore from the basename.
    partial_name="${base#_}"
    if [ "$dir" = "." ]; then
      partial_path="$partial_name"
    else
      partial_path="${dir}/${partial_name}"
    fi

    # `render(partial: "<X>/<name>")` / `render partial: '<X>/<name>'`
    matches+="$(grep -rEn \
      "render[[:space:]]*[(]?[[:space:]]*partial:[[:space:]]*['\"]${partial_path}['\"]" \
      app/ 2>/dev/null || true)"
  else
    # Action template.
    action="$base"

    # `render("<X>/<Y>")` / `render('<X>/<Y>')`
    matches+="$(grep -rEn \
      "render[[:space:]]*\\([[:space:]]*['\"]${rel}['\"]" \
      app/ 2>/dev/null || true)"$'\n'

    # `render(:<Y>)` — symbol form, action-scoped.
    matches+="$(grep -rEn \
      "render[[:space:]]*\\([[:space:]]*:${action}([[:space:],)]|$)" \
      app/ 2>/dev/null || true)"$'\n'

    # `render(action: :<Y>)` / `render(action: "<Y>")` / `action: '<Y>'`
    matches+="$(grep -rEn \
      "render[[:space:]]*\\([^)]*action:[[:space:]]*(:?${action}([[:space:],)]|$)|['\"]${action}['\"])" \
      app/ 2>/dev/null || true)"$'\n'

    # `render(template: "<X>/<Y>")`
    matches+="$(grep -rEn \
      "render[[:space:]]*\\([^)]*template:[[:space:]]*['\"]${rel}['\"]" \
      app/ 2>/dev/null || true)"
  fi

  # Drop blanks and any line that's already an explicit Phlex render
  # (contains `Views::Controllers::`) or a comment line.
  matches="$(printf '%s\n' "$matches" \
    | grep -v '^[[:space:]]*$' \
    | grep -v 'Views::Controllers::' \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' \
    || true)"

  if [ -n "$matches" ]; then
    OFFENDERS+="--- ${erb} ---"$'\n'
    OFFENDERS+="$matches"$'\n\n'
  fi
done <<< "$DELETED"

if [ -n "$OFFENDERS" ]; then
  cat >&2 <<EOF
🚫 Deleted ERB still referenced by name in app/ — blocking commit.

When converting an ERB to Phlex, every \`render("<path>")\` /
\`render(:action)\` / \`render(partial: "<path>")\` /
\`render(template: "<path>")\` call that targeted the ERB needs
to switch to an explicit
\`render(Views::Controllers::...::SomeView.new(...))\`. Otherwise
CI fails with \`ActionView::MissingTemplate: Missing template
<path>\` on the first request that exercises the path.

Offending references:

${OFFENDERS}
Swap each surviving call to the explicit Phlex render. The scan
filters out lines containing \`Views::Controllers::\` and comment
lines, but it's heuristic — if a false positive slips through,
fix the call rather than working around the hook.
EOF
  exit 2
fi

exit 0

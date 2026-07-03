#!/usr/bin/env bash
# Claude Code PreToolUse hook — fires for both Bash (git commit) and
# Edit/Write/MultiEdit (save). Blocks raw Bootstrap component class
# strings in `app/components/` and `app/views/controllers/` and directs
# to the correct Phlex component instead.
#
# Two modes:
#   Bash + git commit → scan staged additions (blocks the commit)
#   Edit/Write        → scan new_string/content (blocks the save)
#
# Exemptions (the component files that legitimately define these classes):
#   app/components/button.rb and app/components/button/**
#   app/components/help/block.rb, help/note.rb, help/collapse_block.rb
#   app/components/list_group/**
#   app/components/modal.rb and app/components/modal/**
#   app/components/alert.rb
#   app/components/alert/link.rb (owns alert-link class)
#   app/components/icon.rb
#   app/components/table.rb
#   app/components/panel.rb and app/components/panel/**
#   app/components/dropdown.rb
#   app/components/link/external.rb (owns target="_blank")
#   app/components/link/collapse_toggle.rb (owns data-toggle="collapse")
#   app/components/form/checkbox_collapse.rb (owns checkbox-driven collapse)
#   app/components/form/location_map.rb (Button::CollapseToggle via type: kwarg)
#   app/components/application_form/input_group_addon.rb (owns input-group-btn)
#   app/components/form/table_accordion.rb (owns panel-group accordion structure)
#   app/views/controllers/observations/namings/reasons_fields.rb (Superform NS — no checkbox_field)
#   app/components/carousel/controls.rb (owns chevron interpolation)
set -euo pipefail

# During a merge commit all changed files are staged, including files
# from main that have pre-existing violations we don't own. Skip
# the commit-mode check; the hook still fires on Edit/Write saves.
[ -f .git/MERGE_HEAD ] && exit 0

INPUT="$(cat)"
TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

in_scope_file() {
  local path="$1"
  case "$path" in
    app/components/*.rb|app/components/**/*.rb|\
    app/views/controllers/**/*.rb) return 0 ;;
    *) return 1 ;;
  esac
}

is_exempt_file() {
  local path="$1"
  case "$path" in
    app/components/button.rb|\
    app/components/button/*|\
    app/components/help/block.rb|\
    app/components/help/note.rb|\
    app/components/help/collapse_block.rb|\
    app/components/list_group/*|\
    app/components/modal.rb|\
    app/components/modal/*|\
    app/components/alert.rb|\
    app/components/alert/link.rb|\
    app/components/icon.rb|\
    app/components/table.rb|\
    app/components/panel.rb|\
    app/components/panel/*|\
    app/components/dropdown.rb|\
    app/components/link/external.rb|\
    app/components/link/collapse_toggle.rb|\
    app/components/form/checkbox_collapse.rb|\
    app/components/form/location_map.rb|\
    app/components/accordion.rb|\
    app/components/application_form/input_group_addon.rb|\
    app/components/application_form/radio_field.rb|\
    app/components/carousel/controls.rb|\
    app/views/controllers/observations/namings/reasons_fields.rb) return 0 ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Extract lines to scan depending on tool
# ---------------------------------------------------------------------------

CONTENT=""
SINGLE_FILE=""

case "$TOOL" in
  Bash)
    COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"
    case "$COMMAND" in
      *"git commit"*) ;;
      *) exit 0 ;;
    esac
    # Collect staged-added lines from in-scope paths (component
    # definitions exempt via pathspec exclude).
    CONTENT="$(git diff --cached -U0 \
      -- \
      'app/components/*.rb' \
      'app/components/**/*.rb' \
      'app/views/controllers/**/*.rb' \
      ':(exclude)app/components/button.rb' \
      ':(exclude)app/components/button/**' \
      ':(exclude)app/components/help/block.rb' \
      ':(exclude)app/components/help/note.rb' \
      ':(exclude)app/components/help/collapse_block.rb' \
      ':(exclude)app/components/list_group/**' \
      ':(exclude)app/components/modal.rb' \
      ':(exclude)app/components/modal/**' \
      ':(exclude)app/components/alert.rb' \
      ':(exclude)app/components/alert/link.rb' \
      ':(exclude)app/components/icon.rb' \
      ':(exclude)app/components/table.rb' \
      ':(exclude)app/components/panel.rb' \
      ':(exclude)app/components/panel/**' \
      ':(exclude)app/components/dropdown.rb' \
      ':(exclude)app/components/link/external.rb' \
      ':(exclude)app/components/link/collapse_toggle.rb' \
      ':(exclude)app/components/form/checkbox_collapse.rb' \
      ':(exclude)app/components/form/location_map.rb' \
      ':(exclude)app/components/accordion.rb' \
      ':(exclude)app/components/application_form/input_group_addon.rb' \
      ':(exclude)app/components/application_form/radio_field.rb' \
      ':(exclude)app/components/carousel/controls.rb' \
      ':(exclude)app/views/controllers/observations/namings/reasons_fields.rb' \
      | grep '^+[^+]' \
      | sed 's/^+//' \
      | grep -v '^[[:space:]]*#' \
      || true)"
    ;;

  Edit|Write)
    SINGLE_FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""')"
    in_scope_file "$SINGLE_FILE" || exit 0
    is_exempt_file "$SINGLE_FILE" && exit 0
    case "$TOOL" in
      Edit)  CONTENT="$(printf '%s' "$INPUT" | jq -r '.tool_input.new_string // ""')" ;;
      Write) CONTENT="$(printf '%s' "$INPUT" | jq -r '.tool_input.content // ""')" ;;
    esac
    CONTENT="$(printf '%s\n' "$CONTENT" | grep -v '^[[:space:]]*#' || true)"
    ;;

  MultiEdit)
    SINGLE_FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""')"
    in_scope_file "$SINGLE_FILE" || exit 0
    is_exempt_file "$SINGLE_FILE" && exit 0
    CONTENT="$(printf '%s' "$INPUT" \
      | jq -r '[.tool_input.edits[].new_string] | join("\n")' 2>/dev/null \
      | grep -v '^[[:space:]]*#' \
      || true)"
    ;;

  *) exit 0 ;;
esac

[ -z "$CONTENT" ] && exit 0

# ---------------------------------------------------------------------------
# Pattern checks — each appends to VIOLATIONS on a match
# ---------------------------------------------------------------------------

VIOLATIONS=""

check() {
  local label="$1"      # human label for the violation
  local component="$2"  # component to use instead
  local pattern="$3"    # ERE to match
  local exclude="${4:-}" # ERE to exclude (false-positive filter)

  local matches
  matches="$(printf '%s\n' "$CONTENT" | grep -En "$pattern" || true)"
  if [ -n "$exclude" ] && [ -n "$matches" ]; then
    matches="$(printf '%s\n' "$matches" | grep -vE "$exclude" || true)"
  fi
  [ -z "$matches" ] && return

  VIOLATIONS="${VIOLATIONS}
  ${label}
    → use ${component}
$(printf '%s\n' "$matches" | sed 's/^/    /')
"
}

# btn classes — exclude:
#   [a-zA-Z]-btn  custom CSS selector classes ending in -btn (find-btn, keep-btn, etc.)
#   btn-group     Bootstrap layout wrapper div (no component equivalent)
check \
  'raw btn class' \
  'Components::Button subclass (Edit/Delete/Post/Patch/Put/Get/Download/ModalToggle/Submit)' \
  'class:[[:space:]]*["'"'"'][^"'"'"']*\bbtn\b' \
  '([a-zA-Z]-btn\b|\bbtn-group\b)'

# help-note / help-block
check \
  'raw help-note / help-block class' \
  'Components::Help::Note.new or Components::Help::Block.new' \
  'class:[[:space:]]*["'"'"'][^"'"'"']*\b(help-note|help-block)\b' \
  ''

# list-group / list-group-item — exclude _class: kwargs (panel_class: etc.)
check \
  'raw list-group class' \
  'Components::ListGroup::Base.new or Components::ListGroup::Item.new' \
  'class:[[:space:]]*["'"'"'][^"'"'"']*\blist-group\b' \
  '_class:'

# modal wrapper (not modal-body/footer/header/title — those are form-internal)
check \
  'raw modal wrapper class' \
  'Components::Modal.new' \
  'class:[[:space:]]*["'"'"'][^"'"'"']*\bmodal\b' \
  'modal-(body|footer|header|title|sm|lg|xl|open)'

# alert — any "alert" or "alert-*" class signals a raw Bootstrap alert.
# alert-link is the one modifier that looks like an exception but isn't —
# use Components::Alert::Link instead (it delegates to Link::Get with the
# class mixed in). alert-dismissible is part of the component itself.
check \
  'raw alert class' \
  'Components::Alert.new(level: :info/:warning/:danger/:success); alert-link → Components::Alert::Link.new(text, path)' \
  'class:[[:space:]]*["'"'"'][^"'"'"']*\balert\b' \
  'alert-dismissible'

# link-icon (glyphicon hand-rolled without Icon component)
check \
  'raw glyphicon/link-icon class' \
  'Components::Icon.new(type: :symbol)' \
  'class:[[:space:]]*["'"'"'][^"'"'"']*\blink-icon\b' \
  ''

# raw glyphicon class (untyped, without going through Icon component)
check \
  'raw glyphicon class' \
  'Components::Icon.new(type: :symbol)' \
  'class:[[:space:]]*["'"'"'][^"'"'"']*\bglyphicon\b' \
  ''

# table — raw table() calls or class: "table …"
# The second alternative uses \btable[^-] (table followed by non-dash) to
# catch standalone "table" base class (real violation) but NOT modifier-only
# class strings like "table-striped table-condensed" (false positives when
# passed as class: kwarg to an existing Components::Table call).
check \
  'raw Bootstrap table class' \
  'Components::Table.new(collection) do |t| … end' \
  '(^[[:space:]]*table\(class:|class:[[:space:]]*["'"'"'][^"'"'"']*\btable[^-])' \
  'table_class:|Components::Table|Table\(|_class:'

# panel — exclude _class: kwargs and custom *-panel CSS class names
check \
  'raw Bootstrap panel class' \
  'Components::Panel.new (with panel_class: for variant overrides)' \
  'class:[[:space:]]*["'"'"'][^"'"'"']*\bpanel\b' \
  'panel_class:|panel-(body|heading|footer|title|group|collapse)|_class:|[a-zA-Z]-panel\b'

# target="_blank" / target: "_blank" — use Link::External instead
# exclude button_target: which is a Phlex component prop, not raw HTML
check \
  'raw target="_blank" on a link' \
  'Components::Link::External.new("text", url)' \
  'target:[[:space:]]*["\x27]_blank["\x27]' \
  'button_target:'

# radio wrapper div — use radio_field helper instead of hand-rolling div.radio
check \
  'raw Bootstrap radio wrapper class' \
  'radio_field(:field, [value, label], ...)' \
  'class:[[:space:]]*["'"'"'][^"'"'"']*\bradio\b' \
  ''

# data-toggle="collapse" — use Link::CollapseToggle instead
# (exempt: collapse_toggle.rb itself; location_map.rb uses Button::CollapseToggle
#  via type: kwarg; reasons_fields.rb and form/details.rb checkbox-driven)
check \
  'raw data-toggle="collapse"' \
  'Components::Link::CollapseToggle.new(target_id: "…")' \
  'toggle:[[:space:]]*["'"'"']collapse["'"'"']' \
  ''

[ -z "$VIOLATIONS" ] && exit 0

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

cat >&2 <<'BANNER'
🚫 Raw Bootstrap component class string(s) in a view or component.

These classes belong inside Phlex components — reach for the component
instead of hand-rolling the Bootstrap structure. Violations:
BANNER

printf '%s\n' "$VIOLATIONS" >&2

cat >&2 <<'FOOTER'

Quick reference:
  btn *            → Components::Button subclass (type: :get/:post/:edit…)
  help-note        → Components::Help::Note.new
  help-block       → Components::Help::Block.new
  list-group       → Components::ListGroup::Base.new do |list| … end
  list-group-item  → Components::ListGroup::Item.new (or list.item in Base)
  modal            → Components::Modal.new
  alert            → Components::Alert.new(level: :info)
  alert-link       → Components::Alert::Link.new(text, path)
  glyphicon        → Components::Icon.new(type: :symbol)
  table            → Components::Table.new(collection) do |t| … end
  panel            → Components::Panel.new
  target="_blank"  → Components::Link::External.new("text", url)
  radio (div)      → radio_field(:field, [value, label], ...)
FOOTER

exit 2

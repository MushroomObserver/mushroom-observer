# frozen_string_literal: true

# Notes section of a form, with a collapsible Bootstrap Panel wrap.
#
# Shared between forms that have user-configurable notes "parts"
# (currently observation; field-slip migration is in flight).
# Owns:
#   - The Panel (collapsible card with "Notes" heading and caret).
#   - The panel body, containing (in order):
#     - `above_help` prose (single-part mode only) — explains what to
#       put in the notes field. Skipped for multi-part mode since
#       custom-notes-fields users probably know what they're doing.
#     - One textarea per part (per the `Part` adapter), namespaced
#       under `:notes`.
#     - Textile-formatting help, always shown at the bottom.
#
# Help content lives inline in the panel body — no collapse-trigger
# in the heading. The panel's own caret already shows/hides everything.
#
# Callers normalize their domain parts (observation strings, field-slip
# `NotesFieldPart` objects, etc.) into uniform `Part` structs before
# passing — see `ObservationForm#observation_form_note_parts`.
class Components::FormNotes < Components::Base
  # Normalized shape for one notes part. `key` becomes the
  # Superform field key under `:notes` (`form[notes][<key>]`),
  # `value` is the current value, `label` is shown above the textarea.
  Part = Data.define(:key, :value, :label)

  prop :form, _Any
  prop :parts, Array
  # Panel id; also used to derive `#{panel_id}_inner` (collapse
  # target) and `#{panel_id}_fields` (the inner div the textareas
  # live in).
  prop :panel_id, String
  prop :expanded, _Boolean, default: false
  prop :single_part_mode, _Boolean, default: false
  # Prose help shown above the textarea in single-part mode (e.g.
  # "Please include any additional information you can think of...").
  # Ignored in multi-part mode — multi-part-fields users typically
  # know what each field is for.
  #
  # Pass a Proc when the help emits Phlex DSL (e.g. `p { ... }`)
  # so rendering is deferred to the right buffer. A plain
  # String/SafeBuffer also works for static content.
  prop :above_help, _Nilable(_Any), default: nil

  def view_template
    render(panel) do |p|
      p.with_heading { plain(:NOTES.l) }
      p.with_body(collapse: true) { render_notes_inner }
    end
  end

  private

  def panel
    Components::Panel.new(
      panel_id: @panel_id,
      collapsible: true,
      collapse_target: "##{@panel_id}_inner",
      expanded: @expanded
    )
  end

  def render_notes_inner
    div(id: "#{@panel_id}_fields") do
      render_above_help if @single_part_mode && @above_help
      @form.namespace(:notes) do |notes_ns|
        @parts.each { |part| render_part(notes_ns, part) }
      end
      render_textile_help
    end
  end

  def render_above_help
    div(class: "help-block") do
      case @above_help
      when Proc then instance_exec(&@above_help)
      else           plain(@above_help)
      end
    end
  end

  # Always-shown textile-formatting help, at the bottom of the body.
  # Same content for both modes.
  def render_textile_help
    div(class: "help-block") { :shared_textile_help.l }
  end

  def render_part(notes_ns, part)
    render(notes_ns.field(part.key).textarea(
             wrapper_options: {
               label: part.label,
               # In single-part mode the panel heading already says
               # "Notes", so the textarea's visible label would be a
               # duplicate. Hide it visually but keep the
               # `<label for="…">` association for screen readers.
               label_sr_only: @single_part_mode
             },
             value: part.value,
             rows: row_count
           ))
  end

  def row_count
    @single_part_mode ? 10 : 1
  end
end

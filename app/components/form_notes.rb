# frozen_string_literal: true

# Notes section of a form, with a collapsible Bootstrap Panel wrap.
#
# Shared between forms that have user-configurable notes "parts"
# (currently observation; field-slip migration is in flight).
# Owns:
#   - The Panel (collapsible card with heading) — every form's notes
#     section renders inside this same wrap shape; callers don't
#     configure it beyond `panel_id:` and `expanded:`.
#   - A `<div id="...">` inside the panel body holding either an
#     empty-state-aware general-help paragraph plus a row of small
#     textareas (one per part), or a single 10-row textarea with an
#     inline help block (when `single_part_mode: true`).
#
# Callers normalize their domain parts (observation strings, field-slip
# `NotesFieldPart` objects, etc.) into uniform `Part` structs before
# passing — see `ObservationForm#observation_form_note_parts` for the
# canonical example.
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
  prop :indent, String, default: ""
  prop :single_part_mode, _Boolean, default: false
  # Help block shown next to the lone textarea in single-part mode.
  # HTML-safe content; rendered via the textarea's `with_help` slot.
  prop :single_part_help, _Nilable(_Any), default: nil

  def view_template
    render(panel) do |p|
      p.with_heading { :NOTES.l }
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
      render_general_help unless @single_part_mode
      div(class: @indent) do
        @form.namespace(:notes) do |notes_ns|
          @parts.each { |part| render_part(notes_ns, part) }
        end
      end
    end
  end

  def render_general_help
    p do
      strong(class: "mr-3") { "#{:NOTES.l}:" }
      CollapseInfoTrigger(target_id: "notes_help")
      CollapseHelpBlock(target_id: "notes_help") do
        :shared_textile_help.l
      end
    end
  end

  def render_part(notes_ns, part)
    textarea = notes_ns.field(part.key).textarea(
      wrapper_options: { label: part.label },
      value: part.value,
      rows: row_count
    )
    # `with_help` slot, not `wrapper_options[:help]`: see
    # `FieldWithHelp#render_help_after_field` (gates on `help_slot`).
    if @single_part_mode && @single_part_help
      textarea.with_help { @single_part_help }
    end
    render(textarea)
  end

  def row_count
    @single_part_mode ? 10 : 1
  end
end

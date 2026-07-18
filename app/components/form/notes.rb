# frozen_string_literal: true

# Notes section of a form, with a collapsible Bootstrap Panel wrap.
#
# Shared between forms that have user-configurable notes "parts"
# (currently observation and field-slip).
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
class Components::Form::Notes < Components::Base
  # Normalized shape for one notes part. `key` becomes the
  # Superform field key under `:notes` (`form[notes][<key>]`),
  # `value` is the current value, `label` is shown above the textarea.
  Part = Data.define(:key, :value, :label)

  # A key some *other* record carries that this record doesn't own yet,
  # offered as a gray "adopt" row: a dropdown of the distinct candidate
  # `options`, which fills a (initially disabled) textarea named
  # `form[notes][<key>]`. Generic; the observation form supplies these
  # from its occurrence's sibling notes (Occurrence#inheritable_notes).
  InheritedField = Data.define(:key, :label, :options)

  prop :form, ::Components::ApplicationForm
  prop :parts, _Array(Part)
  prop :inherited_fields, _Array(InheritedField), default: -> { [] }
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
  prop :above_help, _Nilable(_Union(String, Proc)), default: nil

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
        @notes_name_prefix ||= notes_name_prefix(notes_ns)
        @parts.each { |part| render_part(notes_ns, part) }
      end
      render_inherited_fields if @inherited_fields.any?
      render_textile_help
    end
  end

  # Full HTML name up to (but not including) the per-key segment, e.g.
  # "observation[notes]" -- derived from a real namespaced field so the
  # inherited-row textareas (rendered as plain HTML, outside Superform)
  # submit under the same params as the normal fields.
  def notes_name_prefix(notes_ns)
    notes_ns.field(:__prefix__).dom.name.to_s.chomp("[__prefix__]")
  end

  # Gray "adopt" rows for keys inherited from sibling records. Each row's
  # dropdown fills + enables its textarea via the notes-adopt Stimulus
  # controller; left untouched, the disabled textarea submits nothing and
  # the value stays inherited (shown via the display-time notes merge).
  def render_inherited_fields
    div(class: "notes-inherited mt-3", data: { controller: "notes-adopt" }) do
      Help(content: :form_observations_notes_inherited_help.l)
      @inherited_fields.each { |field| render_inherited_field(field) }
    end
  end

  def render_inherited_field(field)
    div(class: "form-group", data: { notes_row: "" }) do
      label(class: "text-muted") { field.label }
      render_adopt_select(field)
      textarea(
        name: "#{@notes_name_prefix}[#{field.key}]",
        class: "form-control", rows: "1", disabled: true,
        data: { notes_adopt_target: "value" }
      )
    end
  end

  def render_adopt_select(field)
    select(class: "form-control input-sm mb-1",
           data: { action: "change->notes-adopt#adopt" }) do
      option(value: "") { :form_observations_notes_keep_inherited.l }
      field.options.each { |value| option(value: value) { value } }
    end
  end

  def render_above_help
    Help do
      case @above_help
      when Proc then instance_exec(&@above_help)
      else           plain(@above_help)
      end
    end
  end

  # Always-shown textile-formatting help, at the bottom of the body.
  # Same content for both modes.
  def render_textile_help
    Help(content: :shared_textile_help.l)
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

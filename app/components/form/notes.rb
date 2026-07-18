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
  # One notes part. `key` becomes the Superform field key under `:notes`
  # (`form[notes][<key>]`), `value` is the current value, `label` labels
  # the textarea. `adopt_options`, when present, is a list of
  # [source_obs_id, value] the observation form supplies for the primary
  # of an occurrence -- rendered as a dropdown that copies a sibling's
  # value into the textarea. `inherited` marks a key the record doesn't
  # own yet: the textarea starts disabled (submits nothing, so the value
  # stays inherited via the display-time merge) until a value is adopted.
  Part = Data.define(:key, :value, :label, :adopt_options, :inherited) do
    def initialize(key:, value:, label:, adopt_options: nil, inherited: false)
      super
    end
  end

  prop :form, ::Components::ApplicationForm
  prop :parts, _Array(Part)
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
    div(id: "#{@panel_id}_fields", **adopt_controller_attrs) do
      render_above_help if @single_part_mode && @above_help
      Help(content: :form_observations_notes_inherited_help.l) if adopt_rows?
      @form.namespace(:notes) do |notes_ns|
        @notes_name_prefix ||= notes_name_prefix(notes_ns)
        @parts.each { |part| render_part(notes_ns, part) }
      end
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

  def adopt_rows?
    @parts.any? { |part| part.adopt_options.present? }
  end

  def adopt_controller_attrs
    adopt_rows? ? { data: { controller: "notes-adopt" } } : {}
  end

  def render_part(notes_ns, part)
    if part.inherited
      render_inherited_part(part)
    elsif part.adopt_options.present?
      div(data: { notes_row: "" }) do
        render_owned_textarea(notes_ns, part)
        render_adopt_select(part, inherited: false)
      end
    else
      render_owned_textarea(notes_ns, part)
    end
  end

  # A key the record doesn't own yet: a gray row whose disabled textarea
  # submits nothing (so the value stays inherited via the display merge)
  # until the dropdown adopts a sibling value, which fills + enables it.
  def render_inherited_part(part)
    div(class: "form-group",
        data: { notes_row: "", notes_inherited: "" }) do
      label(class: "text-muted") { part.label }
      render_adopt_select(part, inherited: true)
      textarea(name: "#{@notes_name_prefix}[#{part.key}]",
               class: "form-control", rows: "3", style: "resize: vertical;",
               disabled: true, data: { notes_adopt_target: "value" })
    end
  end

  # Dropdown of sibling values to copy in. Options are labelled by their
  # source obs + a truncated preview so a long value (e.g. the iNat
  # imported-data blob) doesn't overflow the control; the full value is
  # the option value, so adopting copies all of it.
  def render_adopt_select(part, inherited:)
    select(class: "form-control mb-1",
           data: { action: "change->notes-adopt#adopt" }) do
      option(value: "") { adopt_default_label(inherited) }
      part.adopt_options.each do |obs_id, value|
        option(value: value) { adopt_option_label(obs_id, value) }
      end
    end
  end

  def adopt_default_label(inherited)
    if inherited
      :form_observations_notes_keep_inherited.l
    else
      :form_observations_notes_keep_current.l
    end
  end

  def adopt_option_label(obs_id, value)
    "Obs #{obs_id}: #{value.squish.truncate(90)}"
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

  def render_owned_textarea(notes_ns, part)
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
             # Occurrence adopt fields can hold long values (the iNat
             # imported-data blob), so give them room like inherited rows.
             rows: part.adopt_options.present? ? 3 : row_count
           ))
  end

  def row_count
    @single_part_mode ? 10 : 1
  end
end

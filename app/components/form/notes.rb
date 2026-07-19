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
  # the textarea.
  #
  # A plain part (`notes_state` nil) renders a normal Superform textarea.
  # An *occurrence* part (a notes key shared with the other observations
  # of the primary's occurrence) carries `adopt_options` -- a list of
  # [source_obs_id, value] sibling values -- and a `notes_state` of one
  # of :set / :hide / :inherit describing what this observation currently
  # shows for the key. It renders a three-state dropdown (Current value /
  # Inherit / Hide / a specific observation's value) that drives the
  # textarea; see `render_occurrence_part`.
  Part = Data.define(:key, :value, :label, :adopt_options, :notes_state) do
    def initialize(key:, value:, label:, adopt_options: nil, notes_state: nil)
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
        @parts.each { |part| render_part(notes_ns, part) }
      end
      render_textile_help
    end
  end

  # Any occurrence (value-source) row -- keyed on notes_state, not
  # adopt_options, since a shared key whose values agree still gets the
  # Current/Inherit/Hide dropdown, just no sibling values to adopt.
  def adopt_rows?
    @parts.any?(&:notes_state)
  end

  def adopt_controller_attrs
    adopt_rows? ? { data: { controller: "notes-adopt" } } : {}
  end

  def render_part(notes_ns, part)
    if part.notes_state
      render_occurrence_part(notes_ns, part)
    else
      render_owned_textarea(notes_ns, part)
    end
  end

  # A notes key shared with the occurrence's other observations. Rendered
  # through the same Superform textarea field as the plain rows (so it
  # gets the matching id + `<label for>` association and submits under
  # `observation[notes][<key>]` identically), with the value-source
  # dropdown in the field's `prepend` slot. The dropdown picks what this
  # observation shows for the key -- its own current value, an inherited
  # value, nothing (hide), or a specific sibling's value -- and drives
  # the textarea. An :inherit row starts disabled (submits nothing, so
  # the value stays inherited via the display-time merge); :set / :hide
  # start enabled so their value (or deliberate blank) submits.
  # :inherit -> disabled (submits nothing, stays inherited). :hide ->
  # readonly not disabled: a readonly field still submits its (blank)
  # value, so the merge suppresses the inherited one, but the user can't
  # type into it (which would silently turn Hide into a stored value) --
  # to change it they use the dropdown. Both render greyed.
  def render_occurrence_part(notes_ns, part)
    inherit = part.notes_state == :inherit
    hide = part.notes_state == :hide
    muted = inherit || hide
    field = notes_ns.field(part.key).textarea(
      wrapper_options: {
        label: part.label,
        wrap_class: muted ? "text-muted" : nil,
        wrap_data: { notes_row: "" }
      },
      value: part.value, rows: 3, disabled: inherit, readonly: hide,
      style: "resize: vertical;", data: { notes_adopt_target: "value" }
    )
    field.with_prepend { render_state_select(part) }
    render(field)
  end

  # Value-source picker: the current state's option is preselected, then
  # the other states, then each distinct sibling value. Selecting an
  # option drives the textarea (see notes-adopt_controller.js). The
  # select isn't tied to the <label> (it drives, not backs, the field),
  # so it carries its own aria-label naming the note it controls.
  def render_state_select(part)
    select(class: "form-control mb-1",
           aria: { label: state_select_aria_label(part) },
           data: { action: "change->notes-adopt#adopt" }) do
      render_state_options(part)
    end
  end

  def state_select_aria_label(part)
    "#{part.label}: #{:form_observations_notes_value_source.l}"
  end

  def render_state_options(part)
    state = part.notes_state
    if state == :set
      state_option(:current, :form_observations_notes_current.l, true)
    end
    state_option(:inherit, :form_observations_notes_inherit.l,
                 state == :inherit)
    state_option(:hide, :form_observations_notes_hide.l, state == :hide)
    part.adopt_options.each do |obs_id, value|
      option(value: value, data: { notes_action: "adopt" }) do
        adopt_option_label(obs_id, value)
      end
    end
  end

  def state_option(action, label, selected)
    option(value: "", selected: selected,
           data: { notes_action: action }) { label }
  end

  # Sibling value labelled by its source obs + a truncated preview so a
  # long value (e.g. the iNat imported-data blob) doesn't overflow the
  # control; the full value is the option value, so adopting copies it all.
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
             rows: row_count
           ))
  end

  def row_count
    @single_part_mode ? 10 : 1
  end
end

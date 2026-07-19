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
  # shows for the key. It renders value + action buttons (This
  # Observation / each sibling / Inherit / Hide / All) that drive the
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
  # This Observation / Inherit / Hide buttons, just no sibling to adopt.
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
  # `observation[notes][<key>]` identically), with the value + action
  # buttons in the field's `prepend` slot. They pick what this observation
  # shows for the key -- its own value, an inherited value, nothing
  # (hide), or a specific sibling's value -- and drive the textarea.
  #
  # :inherit -> disabled (submits nothing, so the value stays inherited).
  # :hide -> readonly, not disabled: a readonly field still submits its
  # (blank) value, so the merge suppresses the inherited one, but can't
  # be typed into (which would silently turn Hide into a stored value) --
  # to change it you click another button. Both render greyed.
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
    field.with_prepend { render_value_buttons(part) }
    render(field)
  end

  # The value-source controls: one clickable button per available value
  # (the primary's own, then each sibling's, each showing its value),
  # then the Inherit / Hide / All actions. Clicking drives the textarea
  # (see notes-adopt_controller.js); the button for the current state is
  # marked active so Inherit and Hide stay distinguishable when the
  # textarea is empty.
  def render_value_buttons(part)
    div(class: "small mb-1", data: { notes_values: "" }) do
      render_source_buttons(part)
      render_action_buttons(part)
    end
  end

  def render_source_buttons(part)
    if part.notes_state == :set && part.value.present?
      render_value_button(:current,
                          :form_observations_notes_this_observation.l,
                          part.value, active: true)
    end
    part.adopt_options.each do |obs_id, value|
      render_value_button(:adopt, "Obs #{obs_id}", value, active: false)
    end
  end

  # A source button labelled by its origin, with the (truncated) value
  # shown beside it. The full raw value rides in data-notes-value so a
  # click copies it verbatim into the textarea.
  def render_value_button(action, label, value, active:)
    div do
      button(type: "button", class: button_class(active),
             data: { notes_action: action, notes_value: value,
                     action: "notes-adopt#choose" }) { label }
      plain(": #{shared_value_preview(value)}")
    end
  end

  def render_action_buttons(part)
    div(class: "mt-1") do
      action_button(:inherit, :form_observations_notes_inherit.l,
                    active: part.notes_state == :inherit)
      action_button(:hide, :form_observations_notes_hide.l,
                    active: part.notes_state == :hide)
      next unless concatenatable?(part)

      action_button(:concatenate, :form_observations_notes_all.l,
                    active: false)
    end
  end

  def action_button(action, label, active:)
    button(type: "button", class: button_class(active),
           data: { notes_action: action, action: "notes-adopt#choose" }) do
      label
    end
  end

  def button_class(active)
    class_names("btn btn-sm btn-default mr-1", "active" => active)
  end

  def shared_value_preview(value)
    value.squish.truncate(120)
  end

  # "All" (concatenate) only makes sense with 2+ distinct values to
  # combine (the primary's own, if any, plus the distinct sibling values).
  def concatenatable?(part)
    own = part.notes_state == :set && part.value.present? ? 1 : 0
    (own + part.adopt_options.size) >= 2
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

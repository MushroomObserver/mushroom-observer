# frozen_string_literal: true

# Notes section of the observation form.
# Renders a collapsible panel with textarea fields for notes parts.
#
# @param form [Components::ApplicationForm] the parent form
# @param observation [Observation] the observation model
# @param user [User] the current user
# @param mode [Symbol] :create or :update
class Components::ObservationFormNotes < Components::Base
  prop :form, _Any
  prop :observation, Observation
  prop :user, User
  prop :mode, Symbol, default: :create

  def view_template
    render(panel) do |p|
      p.with_heading { :NOTES.l }
      p.with_body(collapse: true) { render_body }
    end
  end

  private

  def panel
    Components::Panel.new(
      panel_id: "observation_notes",
      collapsible: true,
      collapse_target: "#observation_notes_inner",
      expanded: panel_expanded?
    )
  end

  def panel_expanded?
    (create? && notes_fields.length > 1) || @observation.notes.present?
  end

  def create?
    @mode == :create
  end

  def render_body
    div(id: "observation_notes_fields") do
      render_general_help unless single_notes_field?
      div(class: notes_indent) do
        @form.namespace(:notes) do |notes_ns|
          notes_fields.each do |part|
            render_notes_field(notes_ns, part)
          end
        end
      end
    end
  end

  def notes_fields
    @notes_fields ||= @observation.form_notes_parts(@user)
  end

  def single_notes_field?
    notes_fields == [Observation.other_notes_part]
  end

  def notes_indent
    # Match original ERB behavior - indent for nested forms
    ""
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

  def render_notes_field(notes_ns, part)
    field_key = @observation.notes_normalized_key(part)
    value = @observation.notes_part_value(part)
    label_text = single_notes_field? ? "#{:NOTES.l}:" : "#{part}:"
    rows = single_notes_field? ? 10 : 1
    help = single_notes_field? ? notes_help : nil

    render(notes_ns.field(field_key).textarea(
             wrapper_options: { label: label_text, help: help },
             value: value,
             rows: rows
           ))
  end

  def notes_help
    [
      p { :form_observations_notes_help.t },
      p { :shared_textile_help.l }
    ].safe_join
  end
end

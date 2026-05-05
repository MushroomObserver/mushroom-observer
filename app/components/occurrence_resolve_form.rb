# frozen_string_literal: true

# Form content for the project membership confirmation modal.
# Renders the intro text, project list, and Cancel/Add All buttons.
#
# Use .modal() to get the full modal wrapper that auto-opens:
#   render(Components::OccurrenceResolveForm.modal(gaps:, ...))
class Components::OccurrenceResolveForm < Components::Base
  register_value_helper :form_authenticity_token

  # Returns a component that wraps the form in a Bootstrap modal.
  def self.modal(gaps:, primary:, user:, selected: nil,
                 occurrence: nil)
    Components::OccurrenceResolveModal.new(
      gaps: gaps, primary: primary, user: user,
      selected: selected, occurrence: occurrence
    )
  end

  def initialize(gaps:, primary:, selected: nil, occurrence: nil)
    super()
    @gaps = gaps
    @primary = primary
    @selected = selected
    @occurrence = occurrence
  end

  def view_template
    render_intro
    render_project_list
    render_form
  end

  private

  def render_intro
    p { :occurrence_resolve_projects_intro.l }
  end

  def render_project_list
    projects = @gaps[:projects]
    return unless projects&.any?

    strong { :occurrence_resolve_projects_projects.l }
    ul do
      projects.each do |project|
        li do
          a(href: project_path(project)) { plain(project.title) }
        end
      end
    end
  end

  def render_form
    if @selected
      render_create_form
    else
      render_edit_form
    end
  end

  def render_create_form
    form(action: occurrences_path, method: "post") do
      authenticity_token_field
      selected_hidden_fields
      render_buttons(
        new_occurrence_path(observation_id: @selected.first.id)
      )
    end
  end

  def render_edit_form
    form(
      action: resolve_projects_occurrence_path(@occurrence),
      method: "post"
    ) do
      authenticity_token_field
      render_buttons(occurrence_path(@occurrence))
    end
  end

  def render_buttons(cancel_path)
    div(class: "text-right mt-3") do
      a(href: cancel_path, class: "btn btn-default mr-3",
        data: { dismiss: "modal" }) do
        :occurrence_resolve_projects_cancel.l
      end
      button(type: "submit",
             name: @selected ? "project_resolution" : "resolution",
             value: "add_all",
             class: "btn btn-primary") do
        :occurrence_resolve_projects_add_all.l
      end
    end
  end

  def authenticity_token_field
    input(type: "hidden", name: "authenticity_token",
          value: form_authenticity_token)
  end

  def selected_hidden_fields
    @selected.each do |obs|
      input(type: "hidden", name: "observation_ids[]",
            value: obs.id)
    end
    input(type: "hidden",
          name: "occurrence[observation_id]",
          value: @selected.first.id)
    input(type: "hidden",
          name: "occurrence[primary_observation_id]",
          value: @primary.id)
  end
end

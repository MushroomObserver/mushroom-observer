# frozen_string_literal: true

# Phlex view for the occurrence creation page.
# Sets page title and renders the form component.
# Optionally overlays a project membership confirmation modal.
module Views::Controllers::Occurrences
  class New < Views::Base
    def initialize(source_obs:, recent_observations:, user:,
                   project_confirm: {})
      super()
      @source_obs = source_obs
      @recent_observations = recent_observations
      @user = user
      @project_confirm = project_confirm
    end

    def view_template
      container_class(:full)
      add_new_title(:create_occurrence_title, :OCCURRENCE)
      # Sibling reference within the module.
      render(Form.new(
               model: Occurrence.new(primary_observation: @source_obs),
               source_obs: @source_obs,
               recent_observations: @recent_observations,
               user: @user
             ))
      render_project_modal if @project_confirm[:gaps]&.any?
    end

    private

    def render_project_modal
      render(Components::Modal.new(
               id: "modal_resolve_projects",
               title: :occurrence_resolve_projects_title.l,
               dialog_class: "modal-dialog modal-lg",
               auto_open: true,
               user: @user
             )) do |m|
        m.with_form_content do
          render(Projects::Form.new(**@project_confirm))
        end
      end
    end
  end
end

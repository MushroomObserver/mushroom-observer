# frozen_string_literal: true

# Phlex view for the occurrence edit page.
# Optionally overlays a project membership confirmation modal.
module Views::Controllers::Occurrences
  class Edit < Views::FullPageBase
    def initialize(occurrence:, observations:, candidates:,
                   user:, project_gaps: nil)
      super()
      @occurrence = occurrence
      @observations = observations
      @candidates = candidates
      @user = user
      @project_gaps = project_gaps
    end

    def view_template
      container_class(:wide)
      # `add_edit_title` is registered as a value helper on
      # `Views::Base`, so it's callable directly — no
      # `view_context.add_edit_title(...)` dispatch needed.
      add_edit_title(@occurrence, user: @user)
      # Sibling reference within the module.
      render(Form.new(
               model: @occurrence,
               observations: @observations.to_a,
               candidates: @candidates,
               user: @user
             ))
      render_project_modal if @project_gaps&.any?
    end

    private

    def render_project_modal
      Modal(id: "modal_resolve_projects",
            title: :occurrence_resolve_projects_title.l,
            dialog_class: "modal-dialog modal-lg",
            auto_open: true,
            user: @user) do |m|
        m.with_form_content do
          render(Projects::Form.new(
                   gaps: @project_gaps,
                   primary: @occurrence.primary_observation,
                   occurrence: @occurrence
                 ))
        end
      end
    end
  end
end

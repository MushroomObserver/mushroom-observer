# frozen_string_literal: true

# Renders action buttons on a project Updates tab matrix box.
# Rendered by `Projects::UpdatesController#index` (the per-obs footer
# inside each matrix box).
#
# When showing excluded observations, only an Add button is shown
# (which also un-excludes). Otherwise, both Add and Exclude are shown.
module Views::Controllers::Projects::Updates
  class ObsFooter < Views::Base
    def initialize(project:, obs:, show_excluded:)
      super()
      @project = project
      @obs = obs
      @show_excluded = show_excluded
    end

    def view_template
      div(id: "update_footer_#{@obs.id}", class: "text-center") do
        render_add_button
        render_exclude_button unless @show_excluded
      end
    end

    private

    def render_add_button
      render(Components::Button::Post.new(
               name: :ADD.t,
               target: add_observation_project_update_path(
                 project_id: @project.id, id: @obs.id,
                 show_excluded: @show_excluded
               ),
               size: :sm, class: "mx-1"
             ))
    end

    def render_exclude_button
      render(Components::Button::Post.new(
               name: :EXCLUDE.t,
               target: exclude_observation_project_update_path(
                 project_id: @project.id, id: @obs.id,
                 show_excluded: @show_excluded
               ),
               size: :sm, class: "mx-1"
             ))
    end
  end
end

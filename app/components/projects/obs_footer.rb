# frozen_string_literal: true

module Components
  module Projects
    # Renders action buttons on a project Updates tab matrix box.
    # When showing excluded observations, only an Add button is shown
    # (which also un-excludes). Otherwise, both Add and Exclude are shown.
    class ObsFooter < Components::Base
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
        button_to(
          :ADD.t,
          add_observation_project_update_path(
            project_id: @project.id, id: @obs.id,
            show_excluded: @show_excluded
          ),
          method: :post,
          class: "btn btn-default btn-sm mx-1",
          form: { data: { turbo: true } }
        )
      end

      def render_exclude_button
        button_to(
          :EXCLUDE.t,
          exclude_observation_project_update_path(
            project_id: @project.id, id: @obs.id,
            show_excluded: @show_excluded
          ),
          method: :post,
          class: "btn btn-default btn-sm mx-1",
          form: { data: { turbo: true } }
        )
      end
    end
  end
end

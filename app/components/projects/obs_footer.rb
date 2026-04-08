# frozen_string_literal: true

module Components
  module Projects
    # Renders Add/Remove button for an observation on the Update tab.
    class ObsFooter < Components::Base
      def initialize(project:, obs:, in_project:)
        super()
        @project = project
        @obs = obs
        @in_project = in_project
      end

      def view_template
        div(id: "update_footer_#{@obs.id}") do
          if @in_project
            render_remove_button
          else
            render_add_button
          end
        end
      end

      private

      def render_remove_button
        button_to(
          :REMOVE.t,
          remove_observation_project_update_path(
            project_id: @project.id, id: @obs.id
          ),
          method: :delete,
          class: "btn btn-default btn-sm",
          data: { turbo: true }
        )
      end

      def render_add_button
        button_to(
          :ADD.t,
          add_observation_project_update_path(
            project_id: @project.id, id: @obs.id
          ),
          method: :post,
          class: "btn btn-default btn-sm",
          data: { turbo: true }
        )
      end
    end
  end
end

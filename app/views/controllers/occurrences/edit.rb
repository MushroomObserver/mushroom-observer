# frozen_string_literal: true

module Views
  module Controllers
    module Occurrences
      # Phlex view for the occurrence edit page.
      # Optionally overlays a project membership confirmation modal.
      class Edit < Views::Base
        register_output_helper :container_class

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
          view_context.add_edit_title(
            :show_occurrence_title.t, @occurrence
          )
          render(Components::OccurrenceEditForm.new(
                   occurrence: @occurrence,
                   observations: @observations,
                   candidates: @candidates,
                   user: @user
                 ))
          render_project_modal if @project_gaps&.any?
        end

        private

        def render_project_modal
          render(Components::OccurrenceResolveForm.modal(
                   gaps: @project_gaps,
                   primary: @occurrence.primary_observation,
                   user: @user,
                   occurrence: @occurrence
                 ))
        end
      end
    end
  end
end

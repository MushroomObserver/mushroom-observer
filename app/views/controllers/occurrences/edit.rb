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
          render(Components::Modal.new(
                   id: "modal_resolve_projects",
                   title: :occurrence_resolve_projects_title.l,
                   dialog_class: "modal-dialog modal-lg",
                   auto_open: true,
                   user: @user
                 )) do |m|
            m.with_body do
              render(Components::OccurrenceResolveForm.new(
                       gaps: @project_gaps,
                       primary: @occurrence.primary_observation,
                       occurrence: @occurrence
                     ))
            end
          end
        end
      end
    end
  end
end

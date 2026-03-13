# frozen_string_literal: true

module Views
  module Controllers
    module Occurrences
      # Phlex view for the occurrence edit page.
      class Edit < Views::Base
        register_output_helper :container_class

        def initialize(occurrence:, observations:, candidates:,
                       user:)
          super()
          @occurrence = occurrence
          @observations = observations
          @candidates = candidates
          @user = user
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
        end
      end
    end
  end
end

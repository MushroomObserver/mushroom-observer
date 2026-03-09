# frozen_string_literal: true

module Views
  module Controllers
    module Occurrences
      # Phlex view for the occurrence show page.
      # Displays observations in matrix boxes with the default first.
      class Show < Views::Base
        register_output_helper :container_class

        def initialize(occurrence:, observations:, user:)
          super()
          @occurrence = occurrence
          @observations = observations
          @user = user
        end

        def view_template
          container_class(:wide)
          view_context.add_show_title(:show_occurrence_title.t,
                                      @occurrence)
          render_location_warning
          render_observation_grid
          render(Components::ObjectFooter.new(
                   user: @user, obj: @occurrence
                 ))
        end

        private

        def render_location_warning
          return unless locations_differ?

          render(Components::Alert.new(
                   message: :show_occurrence_location_differs.t,
                   level: :warning
                 ))
        end

        def locations_differ?
          @observations.map(&:place_name).uniq.size > 1
        end

        def render_observation_grid
          render(Components::MatrixTable.new(
                   objects: @observations,
                   user: @user
                 ))
        end
      end
    end
  end
end

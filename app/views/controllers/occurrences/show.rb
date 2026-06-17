# frozen_string_literal: true

# Phlex view for the occurrence show page.
# Displays observations in matrix boxes with the primary first.
module Views::Controllers::Occurrences
  class Show < Views::Base
    def initialize(occurrence:, observations:, user:)
      super()
      @occurrence = occurrence
      @observations = observations
      @user = user
    end

    def view_template
      container_class(:wide)
      add_show_title(@occurrence, user: @user)
      add_edit_icons(@occurrence, @user)
      render_location_warning
      render_observation_grid
      render(Views::Layouts::VersionsFooter.new(
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

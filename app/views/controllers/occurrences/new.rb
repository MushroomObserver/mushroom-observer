# frozen_string_literal: true

module Views
  module Controllers
    module Occurrences
      # Phlex view for the occurrence creation page.
      # Sets page title and renders the form component.
      class New < Views::Base
        register_output_helper :container_class
        register_output_helper :add_new_title

        def initialize(source_obs:, recent_observations:, user:)
          super()
          @source_obs = source_obs
          @recent_observations = recent_observations
          @user = user
        end

        def view_template
          container_class(:full)
          add_new_title(:create_occurrence_title, :OCCURRENCE)
          render(Components::OccurrenceForm.new(
                   source_obs: @source_obs,
                   recent_observations: @recent_observations,
                   user: @user
                 ))
        end
      end
    end
  end
end

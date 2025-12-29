# frozen_string_literal: true

#
#  = ObservationReviewedState Concern
#
#  This module provides shared logic for getting observation reviewed state
#  from the observation_views association. It supports both eager-loaded and
#  non-eager-loaded contexts.
#
#  == Methods
#  observation_reviewed_state:: Get the reviewed state for an observation
#  eager_loaded_reviewed_state:: Get state from eager-loaded association
#
#  == Usage
#  class MyComponent < Components::Base
#    include ObservationReviewedState
#
#    def view_template
#      reviewed = observation_reviewed_state(@observation, @user)
#    end
#  end
#
################################################################################

module ObservationReviewedState
  extend ActiveSupport::Concern

  included do
    private

    # Get the reviewed state for an observation and user
    #
    # @param observation [Observation] the observation to check
    # @param user [User, nil] the user to check for
    # @return [Boolean, nil] the reviewed state, or nil if no user or no record
    def observation_reviewed_state(observation, user)
      return nil unless user
      return nil unless observation

      if observation.respond_to?(:observation_views)
        eager_loaded_reviewed_state(observation, user)
      else
        # Fallback for contexts where observation_views are not eager-loaded
        ObservationView.find_by(
          observation_id: observation.id,
          user_id: user.id
        )&.reviewed
      end
    end

    # Get reviewed state from eager-loaded observation_views association
    #
    # @param observation [Observation] the observation with loaded association
    # @param user [User] the user to check for
    # @return [Boolean, nil] the reviewed state, or nil if no matching record
    def eager_loaded_reviewed_state(observation, user)
      observation_view = observation.observation_views.detect do |ov|
        ov.user_id == user.id
      end
      observation_view&.reviewed
    end
  end
end

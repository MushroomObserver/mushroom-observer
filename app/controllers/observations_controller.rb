# frozen_string_literal: true

class ObservationsController < ApplicationController
  # These need to be moved into the files where they are actually used.
  require "find"
  require "set"

  include Suggestions
  include Indexes
  include CreateAndEditObservation
  include Show

  # Disable cop: all these methods are defined in files included above.
  # rubocop:disable Rails/LexicallyScopedActionFilter

  before_action :login_required, except: [
    :next_observation,
    :prev_observation,
    :show_obs,
    :show
  ]

  before_action :disable_link_prefetching, except: [
    :create_observation,
    :edit_observation,
    :show_obs,
    :show #,
  ]

  # rubocop:enable Rails/LexicallyScopedActionFilter

  around_action :skip_bullet, if: -> { defined?(Bullet) }, only: [
    # Bullet wants us to eager load species_list.observations when removing
    # an observation from a species_list, but I can't figure out how.
    :edit_observation
  ]
end

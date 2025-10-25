# frozen_string_literal: true

class ObservationsController < ApplicationController
  include Index
  include Show
  include New
  include Create
  include EditAndUpdate
  include Destroy

  # Disable cop: all these methods are defined in files included above.
  # rubocop:disable Rails/LexicallyScopedActionFilter
  before_action :login_required, except: [:show]
  before_action :store_location, only: :show
  # rubocop:enable Rails/LexicallyScopedActionFilter

  around_action :skip_bullet, if: -> { defined?(Bullet) }, only: [
    # Bullet wants us to eager load species_list.observations when removing
    # an observation from a species_list, but I can't figure out how.
    :edit,
    # Bullet wants us to eager load species_list.projecs when adding
    # the observation to a species_list, but I can't figure out how.
    :create
  ]
end

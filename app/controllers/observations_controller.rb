# frozen_string_literal: true

class ObservationsController < ApplicationController
  include Index
  include Show
  include NewAndCreate
  include EditAndUpdate
  include Destroy
  # include Suggestions
  include Map
  # include Download

  # Disable cop: all these methods are defined in files included above.
  # rubocop:disable Rails/LexicallyScopedActionFilter

  before_action :login_required, except: [
    :show
  ]

  before_action :disable_link_prefetching, except: [
    :new,
    :edit,
    :show
  ]

  # rubocop:enable Rails/LexicallyScopedActionFilter

  around_action :skip_bullet, if: -> { defined?(Bullet) }, only: [
    # Bullet wants us to eager load species_list.observations when removing
    # an observation from a species_list, but I can't figure out how.
    :edit
  ]
end

# frozen_string_literal: true

class ObservationsController < ApplicationController
  include Index
  include Show
  include NewAndCreate
  include EditAndUpdate
  include Destroy

  # Disable cop: all these methods are defined in files included above.
  # rubocop:disable Rails/LexicallyScopedActionFilter
  before_action :login_required, except: [
    :show
  ]
  before_action :pass_query_params, only: [
    :show,
    :edit,
    :update
  ]
  # rubocop:enable Rails/LexicallyScopedActionFilter

  around_action :skip_bullet, if: -> { defined?(Bullet) }, only: [
    # Bullet wants us to eager load species_list.observations when removing
    # an observation from a species_list, but I can't figure out how.
    :edit
  ]

  # NOTE: Must be an ivar of ObservationController
  # Defining them in index.rb does not work
  @index_subaction_param_keys = [
    :advanced_search, # Searches come 1st because they may have the other params
    :pattern,
    :look_alikes,
    :related_taxa,
    :name,
    :user,
    :location,
    :where,
    :project,
    :by,
    :q,
    :id
  ].freeze

  @index_subaction_dispatch_table = {
    by: :index_query_results,
    q: :index_query_results,
    id: :index_query_results
  }.freeze
end

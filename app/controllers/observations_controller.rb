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
  before_action :disable_link_prefetching, except: [
    :new,
    :edit,
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

  # NOTE: These ivars need to be ivars of ObservationController
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
    pattern: :observation_search,
    look_alikes: :observations_of_look_alikes,
    related_taxa: :observations_of_related_taxa,
    name: :observations_of_name,
    user: :observations_by_user,
    location: :observations_at_location,
    where: :observations_at_where,
    project: :observations_for_project,
    by: :index_observation,
    q: :index_observation,
    id: :index_observation
  }.freeze
end

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

  # Defined here, rather than in a module,
  # because the superclass needs a class instance variable
  @dispatch_table_for_index_subactions = {
    advanced_search: :advanced_search,
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

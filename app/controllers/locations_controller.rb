# frozen_string_literal: true

require "geocoder"

# Locations controller.
class LocationsController < ApplicationController

  require_dependency "locations/indexes_and_searches"
  require_dependency "locations/show"
  require_dependency "locations/create_and_edit"

  before_action :login_required, except: [
    :advanced_search,
    :help,
    :index,
    :index_location,
    :list_by_country,
    :list_countries,
    :list_locations, # aliased
    :location_search,
    :locations_by_editor,
    :locations_by_user,
    :map_locations,
    :next_location, # aliased
    :prev_location, # aliased
    :show,
    :show_location, # aliased
    :show_next,
    :show_prev,
    :show_past_location
  ]

  before_action :disable_link_prefetching, except: [
    :create_location, # aliased
    :edit,
    :edit_location, # aliased
    :new,
    :show,
    :show_location, # aliased
    :show_past_location
  ]

  before_action :require_successful_user, only: [
  ]

end

# frozen_string_literal: true

# The original MO controller and hence a real mess!
# The Clitocybe of controllers.
#
class ObserverController < ApplicationController
  # These need to be moved into the files where they are actually used.
  require "find"
  require "set"

  # These will mostly form the new ObservationController:
  include Other
  include Suggestions
  include Indexes
  include CreateAndEditObservation
  include ShowObservation

  # These all belong in new controllers:
  include SearchController
  include MarkupController

  # Disable cop: all these methods are defined in files included above.
  # rubocop:disable Rails/LexicallyScopedActionFilter

  before_action :login_required, except: [
    :lookup_observation,
    :next_observation,
    :prev_observation,
    :show_obs,
    :show_observation,
    :test,
    :turn_javascript_nil,
    :turn_javascript_off,
    :turn_javascript_on
  ]
  # except: [
  #   :advanced_search,
  #   :advanced_search_form,
  #   :download_observations,
  #   :hide_thumbnail_map,
  #   :index_observation,
  #   :list_observations,
  #   :lookup_accepted_name,
  #   :lookup_comment,
  #   :lookup_image,
  #   :lookup_location,
  #   :lookup_name,
  #   :lookup_observation,
  #   :lookup_project,
  #   :lookup_species_list,
  #   :lookup_user,
  #   :map_observation,
  #   :map_observations,
  #   :next_observation,
  #   :observation_search,
  #   :observations_by_name,
  #   :observations_of_look_alikes,
  #   :observations_of_name,
  #   :observations_of_related_taxa,
  #   :observations_by_user,
  #   :observations_for_project,
  #   :observations_at_where,
  #   :observations_at_location,
  #   :pattern_search,
  #   :prev_observation,
  #   :print_labels,
  #   :show_obs,
  #   :show_observation,
  #   :test,
  #   :throw_error,
  #   :throw_mobile_error,
  #   :turn_javascript_nil,
  #   :turn_javascript_off,
  #   :turn_javascript_on,
  #   :w3c_tests,
  # ]

  before_action :disable_link_prefetching, except: [
    :create_observation,
    :edit_observation,
    :show_obs,
    :show_observation #,
  ]

  # rubocop:enable Rails/LexicallyScopedActionFilter

  around_action :skip_bullet, if: -> { defined?(Bullet) }, only: [
    # Bullet wants us to eager load species_list.observations when removing
    # an observation from a species_list, but I can't figure out how.
    :edit_observation
  ]
end

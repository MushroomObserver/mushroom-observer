# frozen_string_literal: true

# The original MO controller was called ObserverController and also contained:
# AuthorController
# EmailController
# InfoController
# MarkupController
# NotificationController
# RssLogController
# SearchController
# UserController
# ...hence a real mess! The Clitocybe of controllers.
#
class ObservationsController < ApplicationController
  # These need to be moved into the files where they are actually used.
  require "find"
  require "set"

  require_dependency "observations_controller/show_observation"
  require_dependency "observations_controller/create_and_edit_observation"
  require_dependency "observations_controller/indexes"
  # require_dependency "observations_controller/site_stats"
  require_dependency "observations_controller/suggestions"
  require_dependency "observations_controller/other"
  require_dependency "observations_controller/search"

  # Disable cop: all these methods are defined in files included above.
  # rubocop:disable Rails/LexicallyScopedActionFilter

  before_action :login_required, except: [
    :advanced_search,
    :download_observations,
    :hide_thumbnail_map,
    :index,
    :index_observation,
    :list_observations,
    :map_observation,
    :map_observations,
    :next_observation,
    :observation_search,
    :observations_by_name,
    :observations_of_name,
    :observations_by_user,
    :observations_for_project,
    :observations_at_where,
    :observations_at_location,
    :prev_observation,
    :print_labels,
    :show,
    :show_next,
    :show_obs,
    :show_observation,
    :show_prev,
    :show_site_stats,
    :test,
    :throw_error,
    :throw_mobile_error,
    :turn_javascript_nil,
    :turn_javascript_off,
    :turn_javascript_on,
    :w3c_tests
  ]

  before_action :disable_link_prefetching, except: [
    :create_observation,
    :new,
    :edit_observation,
    :edit,
    :show,
    :show_obs,
    :show_observation
  ]
  # rubocop:enable Rails/LexicallyScopedActionFilter
end

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

  require_dependency "observations/show"
  require_dependency "observations/indexes_and_searches"
  require_dependency "observations/create_and_edit"
  require_dependency "observations/suggestions"
  require_dependency "observations/other"

  # Disable cop: all these methods are defined in files included above.
  # rubocop:disable Rails/LexicallyScopedActionFilter

  before_action :login_required, except: [
    :advanced_search,
    :download_observations,
    :hide_thumbnail_map,
    :index,
    :index_observation,
    :list_observations, #aliased
    :map_observation,
    :map_observations,
    :next_observation, #aliased
    :observation_search,
    :observations_by_name,
    :observations_of_name,
    :observations_by_user,
    :observations_for_project,
    :observations_at_where,
    :observations_at_location,
    :prev_observation, #aliased
    :print_labels,
    :show,
    :show_next,
    :show_obs, #aliased
    :show_observation, #aliased
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
    :create_observation, #aliased
    :new,
    :edit_observation, #aliased
    :edit,
    :show,
    :show_obs, #aliased
    :show_observation #aliased
  ]
  # rubocop:enable Rails/LexicallyScopedActionFilter
end

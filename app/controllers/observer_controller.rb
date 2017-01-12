# encoding: utf-8
#
# The original MO controller and hence a real mess!
# The Clitocybe of controllers.
#
class ObserverController < ApplicationController

  # These need to be moved into the files where they are actually used.
  require "find"
  require "set"
  require_dependency "observation_report"
  require_dependency "pattern_search"

  # These will mostly form the new ObservationController:
  require_dependency "observer_controller/show_observation"
  require_dependency "observer_controller/create_and_edit_observation"
  require_dependency "observer_controller/indexes"
  require_dependency "observer_controller/site_stats"
  require_dependency "observer_controller/other"
  require_dependency "observer_controller/backwards_compatibility"

  # These all belong in new controllers:
  require_dependency "observer_controller/author_controller"
  require_dependency "observer_controller/email_controller"
  require_dependency "observer_controller/info_controller"
  require_dependency "observer_controller/markup_controller"
  require_dependency "observer_controller/notification_controller"
  require_dependency "observer_controller/rss_log_controller"
  require_dependency "observer_controller/search_controller"
  require_dependency "observer_controller/user_controller"

  before_action :login_required, except: MO.themes + [
    :advanced_search,
    :advanced_search_form,
    :ask_webmaster_question,
    :checklist,
    :color_themes,
    :download_observations,
    :hide_thumbnail_map,
    :how_to_help,
    :how_to_use,
    :risd_terminology,
    :index,
    :index_observation,
    :index_rss_log,
    :index_user,
    :intro,
    :list_observations,
    :list_rss_logs,
    :lookup_accepted_name,
    :lookup_comment,
    :lookup_image,
    :lookup_location,
    :lookup_name,
    :lookup_observation,
    :lookup_project,
    :lookup_species_list,
    :lookup_user,
    :map_observations,
    :news,
    :next_observation,
    :observation_search,
    :observations_by_name,
    :observations_of_name,
    :observations_by_user,
    :observations_for_project,
    :observations_at_where,
    :observations_at_location,
    :pattern_search,
    :prev_observation,
    :rss,
    :show_obs,
    :show_observation,
    :show_rss_log,
    :show_site_stats,
    :show_user,
    :test,
    :textile,
    :textile_sandbox,
    :throw_error,
    :throw_mobile_error,
    :translators_note,
    :turn_javascript_nil,
    :turn_javascript_off,
    :turn_javascript_on,
    :user_search,
    :users_by_contribution,
    :w3c_tests,
    :wrapup_2011
  ]

  before_action :disable_link_prefetching, except: [
    :create_observation,
    :edit_observation,
    :show_obs,
    :show_observation,
    :show_user,
  ]
end

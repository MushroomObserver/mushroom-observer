# frozen_string_literal: true

# html used in tabsets
module Tabs
  module ObservationsHelper
    # assemble links for "tabset" for show_observation
    # actually a list of links and the interest icons
    def show_observation_links(obs:, user:, mappable:)
      [
        *show_obs_google_links_for(obs.name),
        general_questions_link(obs, user),
        manage_lists_link(obs, user),
        map_link(mappable),
        *obs_change_links(obs)
      ].reject(&:empty?)
    end

    def show_obs_google_links_for(obs_name)
      return unless obs_name.known?

      [google_images_for(obs_name), google_distribution_map_for(obs_name)]
    end

    def google_images_for(obs_name)
      [:google_images.t, google_images_link(obs_name),
       { class: "google_images_link" }]
    end

    def google_images_link(obs_name)
      format("https://images.google.com/images?q=%s", obs_name.real_text_name)
    end

    def google_distribution_map_for(obs_name)
      [:show_name_distribution_map.t,
       add_query_param(map_name_path(id: obs_name.id)),
       { class: "google_name_distribution_map_link" }]
    end

    def general_questions_link(obs, user)
      return if obs.user.no_emails
      return unless obs.user.email_general_question && obs.user != user

      [:show_observation_send_question.t,
       add_query_param(new_question_for_observation_path(obs.id)),
       { remote: true, onclick: "MOEvents.whirly();",
         class: "send_observer_question_link" }]
    end

    def manage_lists_link(obs, user)
      return unless user

      [:show_observation_manage_species_lists.t,
       add_query_param(edit_observation_species_lists_path(obs.id)),
       { class: "manage_lists_link" }]
    end

    def map_link(mappable)
      return unless mappable

      [:MAP.t, add_query_param(map_locations_path),
       { class: "map_locations_link" }]
    end

    def obs_change_links(obs)
      return unless check_permission(obs)

      [
        [:show_observation_edit_observation.t,
         add_query_param(edit_observation_path(obs.id)),
         { class: "edit_observation_link_#{obs.id}" }],
        [nil, obs, { button: :destroy }]
      ]
    end

    ############################################
    # INDEX

    def index_observation_links(query:)
      links = [
        *at_where_links(query), # maybe multiple links
        index_map_link(query),
        *coerced_query_links(query), # multiple links
        add_to_list_link(query),
        download_as_csv_link(query)
      ]
      links.reject(&:empty?)
    end

    def at_where_links(query)
      # Add some extra links to the index user is sent to if they click on an
      # undefined location.
      return [] unless query.flavor == :at_where

      [
        [:list_observations_location_define.l,
         add_query_param(new_location_path(
                           where: query.params[:user_where]
                         )),
         { class: "new_location_link" }],
        [:list_observations_location_merge.l,
         add_query_param(location_merges_form_path(
                           where: query.params[:user_where]
                         )),
         { class: "merge_locations_link" }],
        [:list_observations_location_all.l,
         add_query_param(locations_path),
         { class: "locations_index_link" }]
      ]
    end

    def index_map_link(query)
      [:show_object.t(type: :map),
       map_observations_path(q: get_query_param(query)),
       { class: "map_observations_link" }]
    end

    # NOTE: coerced_query_link returns an array
    def coerced_query_links(query)
      [
        [*coerced_query_link(query, Location),
         { class: "location_query_link" }],
        [*coerced_query_link(query, Name),
         { class: "name_query_link" }],
        [*coerced_query_link(query, Image),
         { class: "image_query_link" }]
      ]
    end

    def add_to_list_link(query)
      [:list_observations_add_to_list.t,
       add_query_param(edit_species_list_observations_path, query),
       { class: "add_to_list_link" }]
    end

    def download_as_csv_link(query)
      [:list_observations_download_as_csv.t,
       add_query_param(new_observations_download_path, query),
       { class: "download_as_csv_link" }]
    end

    ############################################
    # FORMS

    def new_observation_links
      [[:create_herbarium.t, add_query_param(new_herbarium_path),
        { class: "new_herbarium_link" }]]
    end

    def edit_observation_links(observation:)
      [observation_return_link(observation)]
    end

    def observation_maps_links(query:)
      [
        [*coerced_query_link(query, Observation),
         { class: "observation_query_link" }],
        [*coerced_query_link(query, Location),
         { class: "location_query_link" }]
      ]
    end

    def new_naming_links(observation:)
      [observation_return_link(observation)]
    end

    def edit_naming_links(observation:)
      [observation_return_link(observation)]
    end

    def naming_suggestion_links(observation:)
      [observation_return_link(observation)]
    end

    def observation_list_links(observation:)
      [observation_return_link(observation)]
    end

    def observation_images_edit_links(image:)
      [[:cancel_and_show.t(type: :image),
        add_query_param(image.show_link_args),
        { class: "image_return_link" }]]
    end

    def observation_images_new_links(obs:)
      [
        observation_return_link(obs),
        edit_observation_link(obs)
      ]
    end

    def observation_images_remove_links(obj:)
      [
        observation_return_link(obs),
        edit_observation_link(obs)
      ]
    end

    def observation_images_reuse_links(obs:)
      [
        observation_return_link(obs),
        edit_observation_link(obs)
      ]
    end

    def observation_return_link(obs)
      [:cancel_and_show.t(type: :observation),
       add_query_param(obs.show_link_args),
       { class: "observation_return_link" }]
    end

    def edit_observation_link(obs)
      [:edit_object.t(type: Observation),
       add_query_param(edit_observation_path(obs.id)),
       { class: "edit_observation_link" }]
    end
  end
end

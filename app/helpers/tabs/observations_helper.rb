# frozen_string_literal: true

# html used in tabsets
module Tabs
  module ObservationsHelper
    # assemble links for "tabset" for show_observation
    # actually a list of links and the interest icons
    def show_observation_links(obs:, user:, mappable:)
      [
        *show_obs_google_links_for(obs.name),
        send_observer_question_link(obs, user),
        observation_manage_lists_link(obs, user),
        observation_map_locations_link(mappable),
        *obs_change_links(obs)
      ].reject(&:empty?)
    end

    def show_obs_google_links_for(obs_name)
      return unless obs_name.known?

      [google_images_for_name_link(obs_name),
       google_distribution_map_for_name_link(obs_name)]
    end

    def google_images_for_name_link(obs_name)
      [:google_images.t,
       format("https://images.google.com/images?q=%s",
              obs_name.real_text_name),
       { class: __method__.to_s }]
    end

    def google_distribution_map_for_name_link(obs_name)
      [:show_name_distribution_map.t,
       add_query_param(map_name_path(id: obs_name.id)),
       { class: __method__.to_s }]
    end

    def send_observer_question_link(obs, user)
      return if obs.user.no_emails
      return unless obs.user.email_general_question && obs.user != user

      [:show_observation_send_question.t,
       add_query_param(new_question_for_observation_path(obs.id)),
       { remote: true, onclick: "MOEvents.whirly();",
         class: __method__.to_s }]
    end

    def observation_manage_lists_link(obs, user)
      return unless user

      [:show_observation_manage_species_lists.t,
       add_query_param(edit_observation_species_lists_path(obs.id)),
       { class: __method__.to_s }]
    end

    def observation_map_locations_link(mappable)
      return unless mappable

      [:MAP.t, add_query_param(map_locations_path),
       { class: __method__.to_s }]
    end

    def obs_change_links(obs)
      return unless check_permission(obs)

      [
        edit_observation_link(obs),
        destroy_observation_link(obs)
      ]
    end

    def edit_observation_link(obs)
      [:edit_object.t(type: Observation),
       add_query_param(edit_observation_path(obs.id)),
       { class: "#{__method__}_#{obs.id}" }]
    end

    def destroy_observation_link(obs)
      [nil, obs, { button: :destroy }]
    end

    ############################################
    # INDEX

    def index_observation_links(query:)
      links = [
        *observations_at_where_links(query), # maybe multiple links
        map_observations_link(query),
        *observations_coerced_query_links(query), # multiple links
        observations_add_to_list_link(query),
        observations_download_as_csv_link(query)
      ]
      links.reject(&:empty?)
    end

    def observations_at_where_links(query)
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

    def map_observations_link(query)
      [:show_object.t(type: :map),
       map_observations_path(q: get_query_param(query)),
       { class: __method__.to_s }]
    end

    # NOTE: coerced_query_link returns an array
    def observations_coerced_query_links(query)
      [
        coerced_location_query_link(query),
        coerced_name_query_link(query),
        coerced_image_query_link(query)
      ]
    end

    def observations_add_to_list_link(query)
      [:list_observations_add_to_list.t,
       add_query_param(edit_species_list_observations_path, query),
       { class: __method__.to_s }]
    end

    def observations_download_as_csv_link(query)
      [:list_observations_download_as_csv.t,
       add_query_param(new_observations_download_path, query),
       { class: __method__.to_s }]
    end

    ############################################
    # FORMS

    def observation_form_new_links
      [new_herbarium_link]
    end

    def observation_form_edit_links(obs:)
      [object_return_link(obs)]
    end

    def observation_maps_links(query:)
      [
        coerced_observation_query_link(query),
        coerced_location_query_link(query)
      ]
    end

    def new_naming_links(obs:)
      [object_return_link(obs)]
    end

    def edit_naming_links(obs:)
      [object_return_link(obs)]
    end

    def naming_suggestion_links(obs:)
      [object_return_link(obs)]
    end

    def observation_list_links(obs:)
      [object_return_link(obs)]
    end

    def observation_images_edit_links(image:)
      [object_return_link(image)]
    end

    def observation_images_new_links(obs:)
      [
        object_return_link(obs),
        edit_observation_link(obs)
      ]
    end

    # Note this takes `obj:` not `obs:`
    def observation_images_remove_links(obj:)
      [
        object_return_link(obj),
        edit_observation_link(obj)
      ]
    end

    def observation_images_reuse_links(obs:)
      [
        object_return_link(obs),
        edit_observation_link(obs)
      ]
    end

    def observation_download_links
      [observations_index_link]
    end

    def observations_index_link
      [:download_observations_back.t,
       add_query_param(observations_path),
       { class: __method__.to_s }]
    end
  end
end

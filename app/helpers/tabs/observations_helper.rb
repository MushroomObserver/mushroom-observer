# frozen_string_literal: true

# html used in tabsets
module Tabs
  module ObservationsHelper
    # assemble links for "tabset" for show_observation
    # actually a list of links and the interest icons
    def show_observation_links(obs:, user:)
      [
        google_images_for_name_link(obs.name),
        occurrence_map_for_name_link(obs.name),
        send_observer_question_link(obs, user),
        observation_manage_lists_link(obs, user),
        *obs_change_links(obs)
      ].reject(&:empty?)
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

    ########################################################################
    # Name section -- generates HTML

    # generates HTML using create_tabs with xtrargs { class: "d-block" }
    # the hiccup is that list_descriptions is already HTML
    def name_links_on_mo(name:)
      tabs = create_tabs(obs_related_name_links(name), { class: "d-block" })
      tabs += obs_name_description_links(name)
      tabs += create_tabs([occurrence_map_for_name_link(obs_name)],
                          { class: "d-block" })
      tabs.reject(&:empty?)
    end

    def obs_related_name_links(name)
      [
        show_object_link(name,
                         :show_name.t(name: name.display_name_brief_authors)),
        observations_of_name_link(name),
        observations_of_look_alikes_link(name),
        observations_of_related_taxa_link(name)
      ]
    end

    def observations_of_name_link(name)
      [:show_observation_more_like_this.t,
       observations_path(name: name.id),
       { class: __method__.to_s }]
    end

    def observations_of_look_alikes_link(name)
      [:show_observation_look_alikes.t,
       observations_path(name: name.id, look_alikes: "1"),
       { class: __method__.to_s }]
    end

    def observations_of_related_taxa_link(name)
      [:show_observation_related_taxa.t,
       observations_path(name: name.id, related_taxa: "1"),
       { class: __method__.to_s }]
    end

    # from descriptions_helper
    def obs_name_description_links(name)
      list_descriptions(object: name)&.map do |link|
        tag.div(link)
      end
    end

    def observation_map_link(mappable)
      return unless mappable

      [:MAP.t, add_query_param(map_observation_path),
       { class: __method__.to_s }]
    end

    def name_links_web(name:)
      tabs = create_tabs(observation_web_name_links(name), { class: "d-block" })
      tabs.reject(&:empty?)
    end

    def observation_web_name_links(name)
      [
        mycoportal_name_link(name),
        mycobank_name_search_link(name),
        google_images_for_name_link(name)
      ]
    end

    def mycoportal_name_link(name)
      ["MyCoPortal", mycoportal_url(name),
       { class: __method__.to_s, target: :_blank, rel: :noopener }]
    end

    def mycobank_name_search_link(name)
      ["Mycobank", mycobank_name_search_url(name),
       { class: __method__.to_s, target: :_blank, rel: :noopener }]
    end

    def google_images_for_name_link(obs_name)
      [:google_images.t,
       format("https://images.google.com/images?q=%s",
              obs_name.real_text_name),
       { class: __method__.to_s }]
    end

    def occurrence_map_for_name_link(obs_name)
      [:show_name_distribution_map.t,
       add_query_param(map_name_path(id: obs_name.id)),
       { class: __method__.to_s }]
    end

    ############################################
    # INDEX

    def observations_index_links(query:)
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
        define_location_link(query),
        merge_locations_link(query),
        locations_index_link
      ]
    end

    def observations_index_sorts
      [
        ["rss_log", :sort_by_activity.t],
        ["date", :sort_by_date.t],
        ["created_at", :sort_by_posted.t],
        # kind of redundant to sort by rss_logs, though not strictly ===
        # ["updated_at", :sort_by_updated_at.t],
        ["name", :sort_by_name.t],
        ["user", :sort_by_user.t],
        ["confidence", :sort_by_confidence.t],
        ["thumbnail_quality", :sort_by_thumbnail_quality.t],
        ["num_views", :sort_by_num_views.t]
      ].freeze
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
  end
end

# frozen_string_literal: true

# html used in tabsets
module Tabs
  module ObservationsHelper
    # assemble links for "tabset" for show_observation
    # actually a list of links and the interest icons
    def show_observation_tabs(obs:, user:)
      [
        send_observer_question_tab(obs, user),
        observation_manage_lists_tab(obs, user),
        *obs_change_tabs(obs)&.reject(&:empty?)
      ]
    end

    ########################################################################
    # LINKS FOR PANELS
    #
    # Used in the observation panel

    def send_observer_question_tab(obs, user)
      return if obs.user.no_emails
      return unless obs.user.email_general_question && obs.user != user

      [:show_observation_send_question.t,
       add_query_param(new_question_for_observation_path(obs.id)),
       { remote: true, onclick: "MOEvents.whirly();",
         class: tab_id(__method__.to_s) }]
    end

    # Used in the lists panel
    def observation_manage_lists_tab(obs, user)
      return unless user

      [:show_observation_manage_species_lists.t,
       add_query_param(edit_observation_species_lists_path(obs.id)),
       { class: tab_id(__method__.to_s) }]
    end

    # Name panel -- generates HTML

    # uses create_links_to with extra_args { class: "d-block" }
    # the hiccup here is that list_descriptions is already HTML, an inline list
    def name_links_on_mo(name:)
      tabs = create_links_to(obs_related_name_tabs(name), { class: "d-block" })
      tabs += obs_name_description_tabs(name)
      tabs += create_links_to([occurrence_map_for_name_tab(name)],
                              { class: "d-block" })
      tabs.reject(&:empty?)
    end

    def obs_related_name_tabs(name)
      [
        show_object_tab(name,
                        :show_name.t(name: name.display_name_brief_authors)),
        observations_of_name_tab(name),
        observations_of_look_alikes_tab(name),
        observations_of_related_taxa_tab(name)
      ]
    end

    def observations_of_name_tab(name)
      [:show_observation_more_like_this.t,
       observations_path(name: name.id),
       { class: tab_id(__method__.to_s) }]
    end

    def observations_of_look_alikes_tab(name)
      [:show_observation_look_alikes.t,
       observations_path(name: name.id, look_alikes: "1"),
       { class: tab_id(__method__.to_s) }]
    end

    def observations_of_related_taxa_tab(name)
      [:show_observation_related_taxa.t,
       observations_path(name: name.id, related_taxa: "1"),
       { class: tab_id(__method__.to_s) }]
    end

    # from descriptions_helper
    def obs_name_description_tabs(name)
      list_descriptions(object: name)&.map do |link|
        tag.div(link)
      end
    end

    def observation_map_tab(mappable)
      return unless mappable

      [:MAP.t, add_query_param(map_observation_path),
       { class: tab_id(__method__.to_s) }]
    end

    def name_links_web(name:)
      tabs = create_links_to(observation_web_name_tabs(name),
                             { class: "d-block" })
      tabs.reject(&:empty?)
    end

    def observation_web_name_tabs(name)
      [
        mycoportal_name_tab(name),
        mycobank_name_search_tab(name),
        google_images_for_name_tab(name)
      ]
    end

    def mycoportal_name_tab(name)
      ["MyCoPortal", mycoportal_url(name),
       { class: tab_id(__method__.to_s), target: :_blank, rel: :noopener }]
    end

    def mycobank_name_search_tab(name)
      ["Mycobank", mycobank_name_search_url(name),
       { class: tab_id(__method__.to_s), target: :_blank, rel: :noopener }]
    end

    def google_images_for_name_tab(obs_name)
      [:google_images.t,
       format("https://images.google.com/images?q=%s",
              obs_name.real_text_name),
       { class: tab_id(__method__.to_s), target: :_blank, rel: :noopener }]
    end

    def occurrence_map_for_name_tab(obs_name)
      [:show_name_distribution_map.t,
       add_query_param(map_name_path(id: obs_name.id)),
       { class: tab_id(__method__.to_s) }]
    end

    ############################################
    # INDEX

    def observations_index_tabs(query:)
      links = [
        *observations_at_where_tabs(query), # maybe multiple links
        map_observations_tab(query),
        *observations_coerced_query_tabs(query), # multiple links
        observations_add_to_list_tab(query),
        observations_download_as_csv_tab(query)
      ]
      links.reject(&:empty?)
    end

    def observations_at_where_tabs(query)
      # Add some extra links to the index user is sent to if they click on an
      # undefined location.
      return [] unless query.flavor == :at_where

      [
        define_location_tab(query),
        merge_locations_tab(query),
        locations_index_tab
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

    def map_observations_tab(query)
      [:show_object.t(type: :map),
       map_observations_path(q: get_query_param(query)),
       { class: tab_id(__method__.to_s) }]
    end

    # NOTE: coerced_query_tab returns an array
    def observations_coerced_query_tabs(query)
      [
        coerced_location_query_tab(query),
        coerced_name_query_tab(query),
        coerced_image_query_tab(query)
      ]
    end

    def observations_add_to_list_tab(query)
      [:list_observations_add_to_list.t,
       add_query_param(edit_species_list_observations_path, query),
       { class: tab_id(__method__.to_s) }]
    end

    def observations_download_as_csv_tab(query)
      [:list_observations_download_as_csv.t,
       add_query_param(new_observations_download_path, query),
       { class: tab_id(__method__.to_s) }]
    end

    ############################################
    # FORMS

    def observation_form_new_tabs
      [new_herbarium_tab]
    end

    def observation_form_edit_tabs(obs:)
      [object_return_tab(obs)]
    end

    def observation_maps_tabs(query:)
      [
        coerced_observation_query_tab(query),
        coerced_location_query_tab(query)
      ]
    end

    def naming_form_new_title(obs:)
      :create_naming_title.t(id: obs.id)
    end

    def naming_form_new_tabs(obs:)
      [object_return_tab(obs)]
    end

    def naming_form_edit_title(obs:); end

    def naming_form_edit_tabs(obs:)
      [object_return_tab(obs)]
    end

    def naming_suggestion_tabs(obs:)
      [object_return_tab(obs)]
    end

    def observation_list_tabs(obs:)
      [object_return_tab(obs)]
    end

    def observation_images_edit_tabs(image:)
      [object_return_tab(image)]
    end

    def observation_images_new_tabs(obs:)
      [
        object_return_tab(obs),
        edit_observation_tab(obs)
      ]
    end

    # Note this takes `obj:` not `obs:`
    def observation_images_remove_tabs(obj:)
      [
        object_return_tab(obj),
        edit_observation_tab(obj)
      ]
    end

    def observation_images_reuse_tabs(obs:)
      [
        object_return_tab(obs),
        edit_observation_tab(obs)
      ]
    end

    def observation_download_tabs
      [observations_index_tab]
    end

    def observations_index_tab
      [:download_observations_back.t,
       add_query_param(observations_path),
       { class: tab_id(__method__.to_s) }]
    end

    def obs_change_tabs(obs)
      return unless check_permission(obs)

      [
        edit_observation_tab(obs),
        destroy_observation_tab(obs)
      ]
    end

    def edit_observation_tab(obs)
      [:edit_object.t(type: Observation),
       add_query_param(edit_observation_path(obs.id)),
       { class: "#{tab_id(__method__.to_s)}_#{obs.id}" }]
    end

    def destroy_observation_tab(obs)
      [nil, obs, { button: :destroy }]
    end
  end
end

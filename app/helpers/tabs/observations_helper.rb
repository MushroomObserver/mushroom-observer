# frozen_string_literal: true

# html used in tabsets
module Tabs
  module ObservationsHelper
    # assemble links for "tabset" for show_observation
    # actually a list of links and the interest icons
    def show_observation_links(obs:, user:)
      [
        # *show_obs_google_links_for(obs.name),
        general_questions_link(obs, user),
        manage_lists_link(obs, user)
        # map_link(mappable),
        # *obs_change_links(obs)
      ].reject(&:empty?)
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

    # generates HTML using create_tabs with xtrargs { class: "d-block" }
    # the hiccup is that list_descriptions is already HTML
    def name_links_on_mo(name:, mappable:)
      tabs = create_tabs(obs_related_name_links(name), { class: "d-block" })
      tabs += obs_name_description_links(name)
      tabs += create_tabs([map_link(mappable)], { class: "d-block" })
      tabs.reject(&:empty?)
    end

    def obs_related_name_links(name)
      [
        [:show_name.t(name: name.display_name_brief_authors),
         name_path(name.id), { class: "observation_name_link" }],
        [:show_observation_more_like_this.t,
         observations_path(name: name.id),
         { class: "observations_of_name_link" }],
        [:show_observation_look_alikes.t,
         observations_path(name: name.id, look_alikes: "1"),
         { class: "observations_of_look_alikes_link" }],
        [:show_observation_related_taxa.t,
         observations_path(name: name.id, related_taxa: "1"),
         { class: "observations_of_related_taxa_link" }]
      ]
    end

    # from descriptions_helper
    def obs_name_description_links(name)
      list_descriptions(object: name)&.map do |link|
        tag.div(link)
      end
    end

    def map_link(mappable)
      return unless mappable

      [:MAP.t, add_query_param(map_locations_path),
       { class: "observation_map_locations_link" }]
    end

    # generates HTML
    def name_links_web(name:)
      tabs = create_tabs(obs_web_name_links(name), { class: "d-block" })
      tabs.reject(&:empty?)
    end

    def obs_web_name_links(name)
      [
        ["MyCoPortal", mycoportal_url(name),
         { target: :_blank, rel: :noopener, class: "mycoportal_name_link" }],
        ["Mycobank", mycobank_name_search_url(name),
         { target: :_blank, rel: :noopener, class: "mycobank_name_search_link" }],
        [:google_images.t,
         format("https://images.google.com/images?q=%s", name.real_text_name),
         { class: "google_images_link" }],
        [:show_name_distribution_map.t,
         add_query_param(map_name_path(id: name.id)),
         { class: "google_name_distribution_map_link" }]
      ]
    end

    def obs_icon_size
      "fa-lg"
    end

    def obs_icon_style
      "btn-link"
    end

    def obs_change_links(obs:)
      return [] unless check_permission(obs)

      # icon_size = "fa-lg" # "fa-sm"
      btn_style = "btn-sm btn-link"
      links = []
      links << edit_button(
        target: obs, name: :show_observation_edit_observation.t,
        class: "btn #{btn_style}"
      )
      links << destroy_button(
        target: obs, name: :show_observation_destroy_observation.t,
        class: "btn #{btn_style}"
      )
    end

    # Using link_to in order to enable icons in these links
    def observation_image_edit_links(obs:)
      links = []
      links << obs_add_images_link(obs)
      links << obs_reuse_images_link(obs)
      links << obs_remove_images_link(obs) if obs.images.length.positive?
      links
    end

    # used by observation_image_edit_links
    def obs_add_images_link(obs)
      link_to(
        add_query_param(new_image_for_observation_path(obs.id)),
        class: "btn #{obs_icon_style} observation_add_images_link_#{obs.id}",
        aria: { label: :show_observation_add_images.t },
        data: { toggle: "tooltip", placement: "top",
                title: :show_observation_add_images.t }
      ) do
        # concat(tag.span(:ADD.t, class: "mr-1"))
        concat(icon("fa-regular", "plus", class: obs_icon_size))
      end
    end

    def obs_reuse_images_link(obs)
      link_to(
        add_query_param(reuse_images_for_observation_path(obs.id)),
        class: "btn #{obs_icon_style} observation_reuse_images_link_#{obs.id}",
        aria: { label: :show_observation_reuse_image.t },
        data: { toggle: "tooltip", placement: "top",
                title: :show_observation_reuse_image.t }
      ) do
        # concat(tag.span(:image_reuse_reuse.t, class: "mr-1"))
        concat(icon("fa-regular", "clone", class: obs_icon_size))
      end
    end

    def obs_remove_images_link(obs)
      link_to(
        add_query_param(remove_images_from_observation_path(obs.id)),
        class: "btn #{obs_icon_style} observation_remove_images_link_#{obs.id}",
        aria: { label: :show_observation_remove_images.t },
        data: { toggle: "tooltip", placement: "top",
                title: :show_observation_remove_images.t }
      ) do
        # concat(tag.span(:image_remove_remove.t, class: "mr-1"))
        concat(icon("fa-regular", "trash", class: obs_icon_size))
      end
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

    def edit_observation_links(obs:)
      [observation_return_link(obs)]
    end

    def observation_maps_links(query:)
      [
        [*coerced_query_link(query, Observation),
         { class: "observation_query_link" }],
        [*coerced_query_link(query, Location),
         { class: "location_query_link" }]
      ]
    end

    def new_naming_links(obs:)
      [observation_return_link(obs)]
    end

    def edit_naming_links(obs:)
      [observation_return_link(obs)]
    end

    def naming_suggestion_links(obs:)
      [observation_return_link(obs)]
    end

    def observation_list_links(obs:)
      [observation_return_link(obs)]
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

    # Note this takes `obj:` not `obs:`
    def observation_images_remove_links(obj:)
      [
        observation_return_link(obj),
        edit_observation_link(obj)
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

# frozen_string_literal: true

# html used in tabsets
module Tabs
  module ObservationsHelper
    ########################################################################
    # LINKS FOR PANELS
    #
    # Used in the observation panel

    def send_observer_question_tab(obs)
      InternalLink::Model.new(
        :show_observation_send_question.l, obs,
        new_question_for_observation_path(obs.id),
        html_options: { icon: :email }
      ).tab
    end

    # Used in the lists panel
    # N+1: this looks up User.current.species_lists. Mercifully quick.
    def observation_manage_lists_tab(obs, user)
      return unless user&.species_list_ids&.any?

      InternalLink::Model.new(
        :show_observation_manage_species_lists.l, obs,
        add_q_param(edit_observation_species_lists_path(obs.id)),
        html_options: { icon: :manage_lists }
      ).tab
    end

    # Name panel -- generates HTML

    # uses context_nav_links with extra_args { class: "d-block" }
    # the hiccup here is that list_descriptions is already HTML, an inline list
    def name_links_on_mo(user:, name:)
      tabs = context_nav_links(obs_related_name_tabs(user, name),
                               { class: "d-block" })
      tabs += obs_name_description_tabs(user, name)
      tabs += context_nav_links([occurrence_map_for_name_tab(name)],
                                { class: "d-block" })
      tabs.reject(&:empty?)
    end

    def obs_related_name_tabs(user, name)
      [
        show_object_tab(
          name, :show_name.t(name: name.display_name_brief_authors(user))
        ),
        observations_of_name_tab(name),
        observations_of_look_alikes_tab(name),
        observations_of_related_taxa_tab(name)
      ]
    end

    def observations_of_name_tab(name)
      InternalLink::Model.new(
        :show_observation_more_like_this.l, name,
        observations_path(name: name.id)
      ).tab
    end

    def observations_of_look_alikes_tab(name)
      InternalLink::Model.new(
        :show_observation_look_alikes.l, name,
        observations_path(name: name.id, look_alikes: "1")
      ).tab
    end

    def observations_of_related_taxa_tab(name)
      InternalLink::Model.new(
        :show_observation_related_taxa.l, name,
        observations_path(name: name.id, related_taxa: "1")
      ).tab
    end

    # from descriptions_helper
    def obs_name_description_tabs(user, name)
      list_descriptions(user: user, object: name, type: :name)&.map do |link|
        tag.div(link)
      end
    end

    # This appears to be dead code
    # def observation_map_tab(mappable)
    #   return unless mappable

    #   InternalLink.new(
    #     :MAP.t, add_q_param(map_observation_path)
    #   ).tab
    # end

    # def name_links_web(name:)
    #   tabs = context_nav_links(observation_web_name_tabs(name),
    #                            { class: "d-block" })
    #   tabs.reject(&:empty?)
    # end

    def user_name_links_web(user, name:)
      tabs = context_nav_links(user_observation_web_name_tabs(user, name),
                               { class: "d-block" })
      tabs.reject(&:empty?)
    end

    # def observation_web_name_tabs(name)
    #   [mycoportal_name_tab(name),
    #    mycobank_name_search_tab(name),
    #    google_images_for_name_tab(name)]
    # end

    def user_observation_web_name_tabs(user, name)
      [mycoportal_name_tab(name),
       mycobank_name_search_tab(name),
       user_google_images_for_name_tab(user, name)]
    end

    def observation_hide_thumbnail_map_tab(obs)
      InternalLink::Model.new(
        :show_observation_hide_map.l, obs,
        javascript_hide_thumbnail_map_path(id: obs.id),
        html_options: { icon: :hide }
      ).tab
    end

    def reuse_images_for_observation_tab(obs)
      InternalLink::Model.new(
        :show_observation_reuse_image.l, obs,
        reuse_images_for_observation_path(obs.id),
        html_options: { icon: :reuse }
      ).tab
    end

    ############################################
    # INDEX

    def observations_index_tabs(query:)
      links = [
        *observations_at_where_tabs(query), # maybe multiple links
        map_observations_tab(query),
        *observations_related_query_tabs(query), # multiple links
        observations_add_to_list_tab(query),
        observations_download_as_csv_tab(query),
        new_inat_import_tab
      ]
      links.reject(&:empty?)
    end

    # for debugging
    # def dummy_disable_tab
    #   InternalLink.new(
    #     "Dummy link",
    #     "https://google.com",
    #     html_options: { data: { action: "links#disable" } }
    #   ).tab
    # end

    def observations_at_where_tabs(query)
      # Add some extra links to the index user is sent to if they click on an
      # undefined location.
      return [] if params[:where].blank?

      [define_location_tab(query),
       assign_undefined_location_tab(query),
       locations_index_tab]
    end

    # these are from the observations form
    def define_location_tab(query)
      InternalLink.new(
        :list_observations_location_define.l,
        add_q_param(new_location_path(where: where_param(query.params)))
      ).tab
    end

    # Hack to use the :locations param if it's present and the :search_where
    # param is missing.
    def where_param(query_params)
      query_params[:search_where] || params[:where]
    end

    def assign_undefined_location_tab(query)
      InternalLink.new(
        :list_observations_location_merge.l,
        add_q_param(matching_locations_for_observations_path(
                      where: where_param(query.params)
                    ))
      ).tab
    end

    def observations_index_sorts
      [["rss_log", :sort_by_activity.l],
       ["date", :sort_by_date.l],
       ["created_at", :sort_by_posted.l],
       # kind of redundant to sort by rss_logs, though not strictly ===
       # ["updated_at", :sort_by_updated_at.l],
       ["name", :sort_by_name.l],
       ["user", :sort_by_user.l],
       ["confidence", :sort_by_confidence.l],
       ["thumbnail_quality", :sort_by_thumbnail_quality.l],
       ["num_views", :sort_by_num_views.l]].freeze
    end

    def map_observations_tab(query)
      InternalLink.new(
        :show_object.t(type: :map),
        map_observations_path(q: q_param(query)),
        html_options: { data: { action: "links#disable" } }
      ).tab
    end

    # NOTE: each tab returns an array
    def observations_related_query_tabs(query)
      [related_locations_tab(:Observation, query),
       related_names_tab(:Observation, query),
       related_images_tab(:Observation, query)]
    end

    def observations_add_to_list_tab(query)
      InternalLink.new(
        :list_observations_add_to_list.l,
        add_q_param(species_lists_edit_observations_path, query)
      ).tab
    end

    def observations_download_as_csv_tab(query)
      InternalLink.new(
        :list_observations_download_as_csv.l,
        add_q_param(new_observations_download_path, query)
      ).tab
    end

    ############################################
    # FORMS

    def observation_form_new_tabs
      [new_inat_import_tab, observations_index_tab]
    end

    def observation_form_edit_tabs(obs:)
      [object_return_tab(obs)]
    end

    def observation_maps_tabs(query:)
      [related_observations_tab(:Observation, query), # index of the same obs
       related_locations_tab(:Observation, query)]
    end

    def new_inat_import_tab(query: nil)
      InternalLink.new(
        :create_observation_inat_import_link.l,
        add_q_param(new_inat_import_path, query)
      ).tab
    end

    def naming_form_new_title(obs:)
      :create_naming_title.t(id: obs.id)
    end

    def naming_form_new_tabs(obs:)
      [object_return_tab(obs)]
    end

    def naming_form_edit_title(obs:)
      :edit_naming_title.t(id: obs.id)
    end

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

    def observation_images_reuse_tabs(obs:)
      [object_return_tab(obs),
       edit_observation_tab(obs)]
    end

    def observations_index_tab
      InternalLink.new(
        :cancel_to_index.t(type: :OBSERVATION),
        add_q_param(observations_path)
      ).tab
    end

    def obs_details_links(obs)
      print_labels_button(obs)
    end

    def edit_observation_tab(obs)
      InternalLink::Model.new(
        :edit_object.t(type: Observation), obs,
        edit_observation_path(obs.id),
        html_options: { icon: :edit }
      ).tab
    end

    # def destroy_observation_tab(obs)
    #   InternalLink::Model.new(
    #     :destroy_object.t(TYPE: Observation),
    #     obs, objs,
    #     html_options: { button: :destroy }
    #   ).tab
    # end

    # for show_obs - query is for a single obs label
    def print_labels_button(obs)
      name = :download_observations_print_labels.l
      query = Query.lookup(Observation, id_in_set: [obs.id])
      path = add_q_param(observations_downloads_path(commit: name), query)

      post_button(name: name, path: path, icon: :print,
                  class: "print_label_observation_#{obs.id}",
                  form: { data: { turbo: false } })
    end
  end
end

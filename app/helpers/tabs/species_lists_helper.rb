# frozen_string_literal: true

module Tabs
  module SpeciesListsHelper
    # Moved download link into species_list_logged_in_show_tabs and
    # nixed user: kwarg
    # Can't access this page unless logged in as of 2023
    def species_list_show_tabs(list:, query: nil)
      tabs = species_list_logged_in_show_tabs(list, query)
      return tabs unless check_permission(list)

      tabs += species_list_user_show_tabs(list)
      tabs
    end

    def species_list_logged_in_show_tabs(list, query = nil)
      [
        species_list_download_tab(list),
        species_list_set_source_tab(list),
        clone_species_list_tab(list),
        species_list_add_remove_from_another_list_tab(list, query)
      ]
    end

    def species_list_user_show_tabs(list)
      [
        manage_species_list_projects_tab(list),
        edit_species_list_tab(list),
        clear_species_list_tab(list),
        destroy_species_list_tab(list)
      ]
    end

    def manage_species_list_projects_tab(list)
      InternalLink::Model.new(
        :species_list_show_manage_projects.t,
        list,
        add_query_param(edit_species_list_projects_path(list.id)),
        html_options: { help: :species_list_show_manage_projects_help.l }
      ).tab
    end

    def edit_species_list_tab(list)
      InternalLink::Model.new(
        :species_list_show_edit.t, list,
        add_query_param(edit_species_list_path(list.id))
      ).tab
    end

    def species_list_download_tab(list)
      InternalLink::Model.new(
        :species_list_show_download.t, list,
        add_query_param(new_species_list_download_path(list.id))
      ).tab
    end

    def species_list_set_source_tab(list)
      InternalLink::Model.new(
        :species_list_show_set_source.t, list,
        add_query_param(species_list_path(list.id, set_source: 1)),
        html_options: { help: :species_list_show_set_source_help.l }
      ).tab
    end

    def species_list_add_remove_from_another_list_tab(list, query = nil)
      InternalLink::Model.new(
        :species_list_show_add_remove_from_another_list.t, list,
        add_query_param(
          edit_species_list_observations_path(species_list: list.id), query
        )
      ).tab
    end

    def clone_species_list_tab(list)
      InternalLink::Model.new(
        :species_list_show_clone_list.t, list,
        add_query_param(new_species_list_path(clone: list.id))
      ).tab
    end

    def clear_species_list_tab(list)
      InternalLink::Model.new(
        :species_list_show_clear_list.t, list,
        clear_species_list_path(list.id),
        html_options: { button: :put, class: "text-danger",
                        data: { confirm: :are_you_sure.l } }
      ).tab
    end

    def destroy_species_list_tab(list)
      InternalLink::Model.new(
        :species_list_show_destroy.t, list, list,
        html_options: { button: :destroy }
      ).tab
    end

    def species_list_observations_tabs(list, query)
      [species_list_observations_tab(query),
       species_list_observations_locations_tab(list),
       species_list_observations_names_tab(list),
       species_list_observations_images_tab(list),
       species_list_observations_checklist_tab(list),
       species_list_observations_map_tab(query)]
    end

    def species_list_observations_tab(query)
      InternalLink::Model.new(
        :species_list_show_regular_index.t, SpeciesList,
        add_query_param(observations_path, query),
        html_options: { help: :species_list_show_regular_index_help.t }
      ).tab
    end

    def species_list_obs_query(list)
      controller.create_query(:Observation, species_lists: list)
    end

    def species_list_observations_locations_tab(list)
      related_locations_tab(:Observation, species_list_obs_query(list))
    end

    def species_list_observations_names_tab(list)
      related_names_tab(:Observation, species_list_obs_query(list))
    end

    def species_list_observations_images_tab(list)
      related_images_tab(:Observation, species_list_obs_query(list))
    end

    def species_list_observations_checklist_tab(list)
      InternalLink::Model.new(
        :app_checklist.t, list, checklist_path(species_list_id: list.id)
      ).tab
    end

    def species_list_observations_map_tab(query)
      InternalLink::Model.new(
        :show_object.t(type: :map), SpeciesList,
        add_query_param(map_observations_path, query)
      ).tab
    end

    def species_list_form_new_tabs
      [name_lister_tab]
    end

    def species_list_form_edit_tabs(list:)
      [
        object_return_tab(list),
        species_list_upload_tab(list)
      ]
    end

    def species_list_upload_tab(list)
      InternalLink::Model.new(
        :species_list_upload_title.t, list,
        add_query_param(new_species_list_upload_path(list.id))
      ).tab
    end

    def species_list_edit_project_tabs(list:)
      [object_return_tab(list)]
    end

    def species_list_form_observations_tabs
      [observations_index_return_tab]
    end

    def observations_index_return_tab
      InternalLink.new(
        :species_list_add_remove_cancel.t, add_query_param(observations_path)
      ).tab
    end

    def species_list_form_name_list_tabs
      [name_lister_classic_tab]
    end

    def name_lister_tab
      InternalLink.new(
        :name_lister_title.t, new_species_list_name_lister_path
      ).tab
    end

    def name_lister_classic_tab
      InternalLink.new(
        :name_lister_classic.t, add_query_param(new_species_list_path)
      ).tab
    end

    def species_list_download_tabs(list:)
      [object_return_tab(list)]
    end

    def species_lists_index_sorts(query:)
      [
        ["title",       :sort_by_title.t],
        ["date",        :sort_by_date.t],
        ["user",        :sort_by_user.t],
        ["created_at",  :sort_by_created_at.t],
        [(query.params[:order_by] == :rss_log ? "rss_log" : "updated_at"),
         :sort_by_updated_at.t]
      ]
    end
  end
end

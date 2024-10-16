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
      [:species_list_show_manage_projects.t,
       add_query_param(edit_species_list_projects_path(list.id)),
       { help: :species_list_show_manage_projects_help.l,
         class: tab_id(__method__.to_s) }]
    end

    def edit_species_list_tab(list)
      [:species_list_show_edit.t,
       add_query_param(edit_species_list_path(list.id)),
       { class: tab_id(__method__.to_s) }]
    end

    def species_list_download_tab(list)
      [:species_list_show_download.t,
       add_query_param(new_species_list_download_path(list.id)),
       { class: tab_id(__method__.to_s) }]
    end

    def species_list_set_source_tab(list)
      [:species_list_show_set_source.t,
       add_query_param(species_list_path(list.id, set_source: 1)),
       { class: tab_id(__method__.to_s),
         help: :species_list_show_set_source_help.l }]
    end

    def species_list_add_remove_from_another_list_tab(list, query = nil)
      [:species_list_show_add_remove_from_another_list.t,
       add_query_param(
         edit_species_list_observations_path(species_list: list.id), query
       ),
       { class: tab_id(__method__.to_s) }]
    end

    def clone_species_list_tab(list)
      [:species_list_show_clone_list.t,
       add_query_param(new_species_list_path(clone: list.id)),
       { class: tab_id(__method__.to_s) }]
    end

    def clear_species_list_tab(list)
      [:species_list_show_clear_list.t,
       clear_species_list_path(list.id),
       { button: :put, class: "#{__method__} text-danger",
         data: { confirm: :are_you_sure.l } }]
    end

    def destroy_species_list_tab(list)
      [:species_list_show_destroy.t, list, { button: :destroy }]
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
      [:species_list_upload_title.t,
       add_query_param(new_species_list_upload_path(list.id)),
       { class: tab_id(__method__.to_s) }]
    end

    def species_list_edit_project_tabs(list:)
      [object_return_tab(list)]
    end

    def species_list_form_observations_tabs
      [observations_index_return_tab]
    end

    def observations_index_return_tab
      [:species_list_add_remove_cancel.t, add_query_param(observations_path),
       { class: tab_id(__method__.to_s) }]
    end

    def species_list_form_name_list_tabs
      [name_lister_classic_tab]
    end

    def name_lister_tab
      [:name_lister_title.t, new_species_list_name_lister_path,
       { class: tab_id(__method__.to_s) }]
    end

    def name_lister_classic_tab
      [:name_lister_classic.t, add_query_param(new_species_list_path),
       { class: tab_id(__method__.to_s) }]
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
        [(query.params[:by] == :rss_log ? "rss_log" : "updated_at"),
         :sort_by_updated_at.t]
      ]
    end
  end
end

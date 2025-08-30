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
        write_in_species_list_tab(list),
        species_list_add_remove_from_another_list_tab(list, query)
      ]
    end

    def species_list_user_show_tabs(list)
      [
        add_new_observations_tab(list),
        manage_species_list_projects_tab(list),
        edit_species_list_tab(list),
        clear_species_list_tab(list),
        destroy_species_list_tab(list)
      ]
    end

    def add_new_observations_tab(list)
      InternalLink::Model.new(
        :species_list_show_add_new_observations.t,
        list,
        new_species_list_write_in_path(list.id),
        html_options: { help: :species_list_show_add_new_observations_help.l }
      ).tab
    end

    def manage_species_list_projects_tab(list)
      InternalLink::Model.new(
        :species_list_show_manage_projects.t,
        list,
        edit_species_list_projects_path(list.id),
        html_options: { help: :species_list_show_manage_projects_help.l }
      ).tab
    end

    def edit_species_list_tab(list)
      InternalLink::Model.new(
        :species_list_show_edit.t, list,
        edit_species_list_path(list.id)
      ).tab
    end

    def species_list_download_tab(list)
      InternalLink::Model.new(
        :species_list_show_download.t, list,
        add_q_param(new_species_list_download_path(list.id))
      ).tab
    end

    def species_list_set_source_tab(list)
      InternalLink::Model.new(
        :species_list_show_set_source.t, list,
        add_q_param(species_list_path(list.id, set_source: 1)),
        html_options: { help: :species_list_show_set_source_help.l }
      ).tab
    end

    def species_list_show_tab(list)
      InternalLink::Model.new(
        :cancel_and_show.t(TYPE: list.type_tag), list,
        species_list_path(list.id)
      ).tab
    end

    def species_list_add_remove_from_another_list_tab(list, query = nil)
      InternalLink::Model.new(
        :species_list_show_add_remove_from_another_list.t, list,
        add_q_param(
          edit_species_list_observations_path(species_list: list.id), query
        )
      ).tab
    end

    def clone_species_list_tab(list)
      InternalLink::Model.new(
        :species_list_show_clone_list.t, list,
        new_species_list_path(clone: list.id)
      ).tab
    end

    def write_in_species_list_tab(list)
      InternalLink::Model.new(
        :species_list_show_write_in.t, list,
        new_species_list_write_in_path(id: list.id)
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

    def species_list_form_new_tabs
      [name_lister_tab, species_list_index_tab]
    end

    def species_list_write_in_form_tabs(list)
      [species_list_show_tab(list)]
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
        new_species_list_upload_path(list.id)
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
        :species_list_add_remove_cancel.t, add_q_param(observations_path)
      ).tab
    end

    def species_list_form_name_list_tabs
      [species_list_create_tab]
    end

    def name_lister_tab
      InternalLink.new(
        :name_lister_title.t, new_species_list_name_lister_path
      ).tab
    end

    def species_list_index_tab
      InternalLink.new(
        :cancel_to_index.t(type: :SPECIES_LIST),
        add_q_param(species_lists_path)
      ).tab
    end

    def species_list_create_tab
      InternalLink.new(
        :create_object.t(type: :SPECIES_LIST),
        new_species_list_path
      ).tab
    end

    def species_list_download_tabs(list:)
      [object_return_tab(list)]
    end

    def species_lists_for_user_tab(user)
      InternalLink.new(
        :app_your_lists.l, species_lists_path(by_user: user.id)
      ).tab
    end

    def species_lists_index_sorts(query: nil)
      [
        ["title",       :sort_by_title.t],
        ["date",        :sort_by_date.t],
        ["user",        :sort_by_user.t],
        ["created_at",  :sort_by_created_at.t],
        [(query&.params&.dig(:order_by) == :rss_log ? "rss_log" : "updated_at"),
         :sort_by_updated_at.t]
      ]
    end
  end
end

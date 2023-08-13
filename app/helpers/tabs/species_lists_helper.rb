# frozen_string_literal: true

module Tabs
  module SpeciesListsHelper
    # Moved download link into logged_in_show_links and nixed user: kwarg
    # Can't access this page unless logged in as of 2023
    def species_list_show_links(list:)
      links = species_list_logged_in_show_links(list)
      return links unless check_permission(list)

      links += species_list_user_show_links(list)
      links
    end

    def species_list_logged_in_show_links(list)
      [
        species_list_download_link(list),
        species_list_set_source_link(list),
        clone_species_list_link(list),
        species_list_add_remove_from_another_list_link(list)
      ]
    end

    def species_list_user_show_links(list)
      [
        manage_species_list_projects_link(list),
        edit_species_list_link(list),
        clear_species_list_link(list),
        destroy_species_list_link(link)
      ]
    end

    def manage_species_list_projects_link(list)
      [:species_list_show_manage_projects.t,
       add_query_param(edit_species_list_projects_path(list.id)),
       { help: :species_list_show_manage_projects_help.l,
         class: __method__.to_s }]
    end

    def edit_species_list_link(list)
      [:species_list_show_edit.t,
       add_query_param(edit_species_list_path(list.id)),
       { class: __method__.to_s }]
    end

    def species_list_download_link(list)
      [:species_list_show_download.t,
       add_query_param(new_species_list_download_path(list.id)),
       { class: __method__.to_s }]
    end

    def species_list_set_source_link(list)
      [:species_list_show_set_source.t,
       add_query_param(species_list_path(list.id, set_source: 1)),
       { class: __method__.to_s,
         help: :species_list_show_set_source_help.l }]
    end

    def species_list_add_remove_from_another_list_link(list)
      [:species_list_show_add_remove_from_another_list.t,
       add_query_param(
         edit_species_list_observations_path(species_list: list.id)
       ),
       { class: __method__.to_s }]
    end

    def clone_species_list_link(list)
      [:species_list_show_clone_list.t,
       add_query_param(new_species_list_path(clone: list.id)),
       { class: __method__.to_s }]
    end

    def clear_species_list_link(list)
      [:species_list_show_clear_list.t,
       clear_species_list_path(list.id),
       { button: :put, class: "#{__method__} text-danger",
         data: { confirm: :are_you_sure.l } }]
    end

    def destroy_species_list_link(_link)
      [:species_list_show_destroy.t, list, { button: :destroy }]
    end

    def species_list_form_new_links
      [name_lister_link]
    end

    def species_list_form_edit_links(list:)
      [
        object_return_link(list),
        species_list_upload_link(list)
      ]
    end

    def species_list_upload_link(list)
      [:species_list_upload_title.t,
       add_query_param(new_species_list_upload_path(list.id)),
       { class: __method__.to_s }]
    end

    def species_list_edit_project_links(list:)
      [object_return_link(list)]
    end

    def species_list_form_observations_links
      [observations_index_return_link]
    end

    def observations_index_return_link
      [:species_list_add_remove_cancel.t, add_query_param(observations_path),
       { class: __method__.to_s }]
    end

    def species_list_form_name_list_links
      [name_lister_classic_link]
    end

    def name_lister_link
      [:name_lister_title.t, new_species_list_name_lister_path,
       { class: __method__.to_s }]
    end

    def name_lister_classic_link
      [:name_lister_classic.t, add_query_param(new_species_list_path),
       { class: __method__.to_s }]
    end

    def species_list_download_links(list:)
      [object_return_link(list)]
    end
  end
end

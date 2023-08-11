# frozen_string_literal: true

module Tabs
  module SpeciesListsHelper
    def species_list_show_links(list:, user:)
      links = [
        [:species_list_show_download.t,
         add_query_param(new_species_list_download_path(list.id)),
         { class: "species_list_download_link" }]
      ]
      links += species_list_logged_in_show_links(list) if user
      return unless check_permission(list)

      links += species_list_user_show_links(list)
      links
    end

    def species_list_logged_in_show_links(list)
      [
        [:species_list_show_set_source.t,
         add_query_param(species_list_path(list.id, set_source: 1)),
         { class: "species_list_set_source_link",
           help: :species_list_show_set_source_help.l }],
        [:species_list_show_clone_list.t,
         add_query_param(new_species_list_path(clone: list.id)),
         { class: "species_list_clone_link" }],
        [:species_list_show_add_remove_from_another_list.t,
         add_query_param(
           edit_species_list_observations_path(species_list: list.id)
         ),
         { class: "species_list_add_remove_from_another_list_link" }]
      ]
    end

    def species_list_user_show_links(list)
      [
        [:species_list_show_manage_projects.t,
         add_query_param(edit_species_list_projects_path(list.id)),
         { help: :species_list_show_manage_projects_help.l,
           class: "edit_species_list_projects_link" }],
        [:species_list_show_edit.t,
         add_query_param(edit_species_list_path(list.id)),
         { class: "edit_species_list_link" }],
        [:species_list_show_clear_list.t,
         clear_species_list_path(list.id),
         { button: :put, class: "clear_species_list_link text-danger",
           data: { confirm: :are_you_sure.l } }],
        [:species_list_show_destroy.t, list, { button: :destroy }]
      ]
    end

    def species_list_form_new_links
      [
        [:name_lister_title.t, new_species_list_name_lister_path,
         { class: "name_lister_link" }]
      ]
    end

    def species_list_form_edit_links(list:)
      [
        species_list_return_link(list),
        [:species_list_upload_title.t,
         add_query_param(new_species_list_upload_path(list.id)),
         { class: "species_list_upload_link" }]
      ]
    end

    def species_list_edit_project_links(list:)
      [species_list_return_link(list)]
    end

    def species_list_form_observations_links
      [[:species_list_add_remove_cancel.t, add_query_param(observations_path),
        { class: "observation_return_link" }]]
    end

    def species_list_form_name_list_links
      [[:name_lister_classic.t, add_query_param(new_species_list_path),
        { class: "name_lister_classic_link" }]]
    end

    # different wording
    def species_list_download_links(list:)
      [[:species_list_download_back.t,
        add_query_param(species_list_path(list)),
        { class: "species_list_return_link" }]]
    end

    def species_list_return_link(list)
      [:cancel_and_show.t(type: :species_list),
       add_query_param(list.show_link_args),
       { class: "species_list_return_link" }]
    end
  end
end

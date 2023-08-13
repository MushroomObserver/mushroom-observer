# frozen_string_literal: true

module Tabs
  module ChecklistsHelper
    def checklist_show_links(user:, project:, list:)
      if user
        checklist_for_user_links(user)
      elsif project
        checklist_for_project_links(project)
      elsif list
        checklist_for_species_list_links(list)
      else
        checklist_for_site_links
      end
    end

    def checklist_for_user_links(user)
      [
        user_profile_link(user),
        user_observations_link(user),
        email_user_question_link(user)
      ]
    end

    def checklist_for_project_links(project)
      [
        show_object_link(project),
        object_index_link(project)
      ]
    end

    def checklist_for_species_list_links(list)
      links = [
        show_object_link(list)
      ]
      if check_permission(list)
        links += [
          edit_species_list_link(list)
        ]
      end
      links
    end

    def checklist_for_site_links
      [
        site_contributors_link,
        info_site_stats_link
      ]
    end

    def site_checklist_link
      [:site_stats_observed_taxa.t, checklist_path,
       { class: __method__.to_s }]
    end
  end
end

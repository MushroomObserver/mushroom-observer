# frozen_string_literal: true

module Tabs
  module ChecklistsHelper
    def checklist_show_title(user:, project:, list:)
      if user
        :checklist_for_user_title.t(user: user.legal_name)
      elsif project
        :checklist_for_project_title.t(project: project.title)
      elsif list
        :checklist_for_species_list_title.t(list: list.title)
      else
        :checklist_for_site_title.t
      end
    end

    def checklist_show_tabs(user:, project:, list:)
      if user
        checklist_for_user_tabs(user)
      elsif project
        checklist_for_project_tabs(project)
      elsif list
        checklist_for_species_list_tabs(list)
      else
        checklist_for_site_tabs
      end
    end

    def checklist_for_user_tabs(user)
      [
        user_profile_tab(user),
        user_observations_tab(user),
        email_user_question_tab(user)
      ]
    end

    def checklist_for_project_tabs(project)
      [
        show_object_tab(project),
        object_index_tab(project)
      ]
    end

    def checklist_for_species_list_tabs(list)
      links = [
        show_object_tab(list)
      ]
      if check_permission(list)
        links += [
          edit_species_list_tab(list)
        ]
      end
      links
    end

    def checklist_for_site_tabs
      [
        site_contributors_tab,
        info_site_stats_tab
      ]
    end

    def site_checklist_tab
      [:site_stats_observed_taxa.t, checklist_path,
       { class: tab_id(__method__.to_s) }]
    end
  end
end

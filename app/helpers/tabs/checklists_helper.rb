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
        [:show_object.t(type: :profile), user_path(user.id),
         { class: "user_profile_link" }],
        [:show_objects.t(type: :observation),
         observations_path(user: user.id),
         { class: "user_observations_link" }],
        [:show_user_email_to.t(name: user.legal_name),
         emails_ask_user_question_path(user.id),
         { class: "email_user_question_link" }]
      ]
    end

    def checklist_for_project_links(project)
      [
        [:show_object.t(type: :project), project_path(project.id),
         { class: "project_link" }],
        [:list_objects.t(type: :project), projects_path,
         { class: "projects_index_link" }]
      ]
    end

    def checklist_for_species_list_links(list)
      links = [
        [:show_object.t(type: :project), species_list_path(list.id),
         { class: "species_list_link" }]
      ]
      if check_permission(list)
        links += [
          [:edit_object.t(type: :species_list),
           edit_species_list_path(list.id),
           { class: "edit_species_list_link" }]
        ]
      end
      links
    end

    def checklist_for_site_links
      [
        contributors_link,
         info_site_stats_link
      ]
    end
  end
end

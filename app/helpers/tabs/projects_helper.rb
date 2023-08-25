# frozen_string_literal: true

module Tabs
  module ProjectsHelper
    def project_show_tabs(project:, user:)
      links = [
        projects_index_tab,
        project_admin_request_tab(project)
      ]
      links << project_add_members_tab(project) if project.is_admin?(user)
      links += project_mod_tabs(project) if check_permission(project)
      links
    end

    def project_form_new_tabs
      [projects_index_tab]
    end

    def project_form_edit_tabs(project:)
      links = [
        projects_index_tab,
        object_return_tab(project)
      ]
      links << destroy_project_tab(project) if check_permission(project)
      links
    end

    def projects_index_tabs
      [new_project_tab]
    end

    def project_members_form_new_tabs(project:)
      [object_return_tab(project)]
    end

    def project_member_form_edit_tabs(project:)
      links = [
        projects_index_tab,
        object_return_tab(project)
      ]
      return unless check_permission(project)

      # Note this is just an edit_project_tab with different wording
      links << change_member_status_tab(project)
    end

    def projects_index_tab
      [:app_list_projects.t, projects_path,
       { class: tab_id(__method__.to_s) }]
    end

    def new_project_tab
      [:list_projects_add_project.t, add_query_param(new_project_path),
       { class: tab_id(__method__.to_s) }]
    end

    def change_member_status_tab(project)
      [:change_member_status_edit.t,
       edit_project_path(project.id),
       { class: tab_id(__method__.to_s) }]
    end

    def project_add_members_tab(project)
      [:show_project_add_members.t,
       add_query_param(new_project_member_path(project_id: project.id)),
       { class: tab_id(__method__.to_s) }]
    end

    def project_admin_request_tab(project)
      [:show_project_admin_request.t,
       add_query_param(
         new_project_admin_request_path(project_id: project.id)
       ), { class: tab_id(__method__.to_s) }]
    end

    def project_mod_tabs(project)
      [
        edit_project_tab(project),
        destroy_project_tab(project)
      ]
    end

    def edit_project_tab(project)
      [:show_project_edit.t,
       add_query_param(edit_project_path(project.id)),
       { class: tab_id(__method__.to_s) }]
    end

    def destroy_project_tab(project)
      [nil, project, { button: :destroy }]
    end

    # Add some alternate sorting criteria.
    def projects_index_sorts
      [
        ["name", :sort_by_title.t],
        ["created_at",  :sort_by_created_at.t],
        ["updated_at",  :sort_by_updated_at.t]
      ].freeze
    end
  end
end

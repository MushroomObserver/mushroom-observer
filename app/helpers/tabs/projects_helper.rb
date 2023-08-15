# frozen_string_literal: true

module Tabs
  module ProjectsHelper
    def project_show_links(project:, user:)
      links = [
        projects_index_link,
        project_admin_request_link(project)
      ]
      links << project_add_members_link(project) if project.is_admin?(user)
      links += project_mod_links(project) if check_permission(project)
      links
    end

    def project_form_new_links
      [projects_index_link]
    end

    def project_form_edit_links(project:)
      links = [
        projects_index_link,
        object_return_link(project)
      ]
      links << destroy_project_link(project) if check_permission(project)
      links
    end

    def projects_index_links
      [new_project_link]
    end

    def project_members_form_new_links(project:)
      [object_return_link(project)]
    end

    def project_member_form_edit_links(project:)
      links = [
        projects_index_link,
        object_return_link(project)
      ]
      return unless check_permission(project)

      # Note this is just an edit_project_link with different wording
      links << change_member_status_link(project)
    end

    def projects_index_link
      [:app_list_projects.t, projects_path,
       { class: __method__.to_s }]
    end

    def new_project_link
      [:list_projects_add_project.t, add_query_param(new_project_path),
       { class: __method__.to_s }]
    end

    def change_member_status_link(project)
      [:change_member_status_edit.t,
       edit_project_path(project.id),
       { class: __method__.to_s }]
    end

    def project_add_members_link(project)
      [:show_project_add_members.t,
       add_query_param(new_project_member_path(project_id: project.id)),
       { class: __method__.to_s }]
    end

    def project_admin_request_link(project)
      [:show_project_admin_request.t,
       add_query_param(
         new_project_admin_request_path(project_id: project.id)
       ), { class: __method__.to_s }]
    end

    def project_mod_links(project)
      [
        edit_project_link(project),
        destroy_project_link(project)
      ]
    end

    def edit_project_link(project)
      [:show_project_edit.t,
       add_query_param(edit_project_path(project.id)),
       { class: __method__.to_s }]
    end

    def destroy_project_link(project)
      [nil, project, { button: :destroy }]
    end
  end
end

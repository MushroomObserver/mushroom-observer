# frozen_string_literal: true

module Tabs
  module ProjectsHelper
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

    def add_project_banner(project)
      add_page_title(link_to_object(project))

      if project.location
        content_for(:location) do
          tag.b(link_to(project.place_name, location_path(project.location.id)))
        end
      end

      if project.start_date && project.end_date
        content_for(:date_range) do
          tag.b(project.date_range)
        end
      end

      add_background_image(project.image)
    end

    def add_background_image(image)
      return unless image

      content_for(:background_image) do
        image_tag(image.large_url, class: "image-title")
      end
    end
  end
end

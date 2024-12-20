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
      project_tabs(project)
    end

    def add_background_image(image)
      return unless image

      content_for(:background_image) do
        image_tag(image.large_url, class: "image-title")
      end
    end

    def build_tab(link_text, link, controller)
      tag.li(class: "nav-item") do
        classes = "nav-link #{active_tab?(controller) ? "active" : ""}"
        link_to(link_text, link,
                { class: classes })
      end
    end

    def violations_tab(project)
      violations_count = project.count_violations
      classes = if violations_count.zero?
                  "nav-link #{active_tab?("violations") ? "active" : ""}"
                else
                  "nav-link text-warning"
                end

      tag.li(class: "nav-item") do
        link_to("#{violations_count} #{:CONSTRAINT_VIOLATIONS.l}",
                project_violations_path(project_id: project.id),
                { class: classes })
      end
    end

    def project_tabs(project)
      tabs = []
      tabs << build_tab(:SUMMARY.t, project_path(id: project.id), "projects")

      if project.observations.any?
        tabs << build_tab("#{project.observations.length} #{:OBSERVATIONS.l}",
                          observations_path(project: project.id),
                          "observations")
        tabs << build_tab("#{project.name_count} #{:NAMES.l}",
                          checklist_path(project_id: project.id),
                          "checklists")
        tabs << build_tab("#{project.location_count} #{:LOCATIONS.l}",
                          project_locations_path(project_id: project.id),
                          "locations")
      end
      tabs << build_tab("#{project.user_group.users.count} #{:MEMBERS.l}",
                        project_members_path(project.id),
                        "members")
      tabs << violations_tab(project)

      content_for(:project_tabs) do
        tag.ul(safe_join(tabs), class: "nav nav-tabs")
      end
    end

    # Helper method to determine active tab
    def active_tab?(tab_name)
      controller_name == tab_name
    end
  end
end

# frozen_string_literal: true

# Renders the project nav-tabs strip and, on a project-admin page, the
# admin sub-tabs strip below it. Rendered via the `add_project_banner`
# helper alongside `Banner`, so every project page gets the same tab
# chrome regardless of which page is active -- no caller renders
# `AdminSubtabs` itself.
module Views::Controllers::Projects
  class ProjectNavs < Views::Base
    prop :project, ::Project
    prop :user, _Nilable(User), default: nil
    prop :current_tab, _Nilable(String), default: nil

    # Every controller that renders the admin sub-tabs below the main
    # tabs (see Tab::Project::AdminSubtabs), keyed to the sub-tab it
    # lands on.
    ADMIN_SUBTAB_CONTROLLERS = {
      "projects/admin" => "details",
      "projects/members" => "members",
      "projects/aliases" => "aliases",
      "field_slips" => "field_slips",
      "projects/field_slips" => "field_slips",
      "projects/external_sites" => "external_sites"
    }.freeze

    def view_template
      render_project_tabs
      render_project_subtabs if project_admin_page?
    end

    private

    def render_project_tabs
      tab_margin_class = no_tab_bottom_margin? ? "mt-3" : "my-3"

      NavTabs(
        id: "project_tabs", class: tab_margin_class,
        current: @current_tab,
        tabs: ::Tab::Project::Banner.new(
          project: @project, user: @user
        )
      )
    end

    def render_project_subtabs
      render(AdminSubtabs.new(
               project: @project, current_subtab: current_admin_subtab
             ))
    end

    def no_tab_bottom_margin?
      project_page? || project_admin_page?
    end

    def project_page?
      controller.controller_name == "projects" &&
        controller.action_name == "show"
    end

    def project_admin_page?
      ADMIN_SUBTAB_CONTROLLERS.key?(controller.controller_path)
    end

    def current_admin_subtab
      ADMIN_SUBTAB_CONTROLLERS[controller.controller_path]
    end
  end
end

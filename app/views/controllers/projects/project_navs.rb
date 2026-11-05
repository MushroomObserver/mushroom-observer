# frozen_string_literal: true

# Renders the project nav-tabs strip and, on an admin- or
# observation-sub-tab page, the matching sub-tabs strip below it.
# Rendered via the `add_project_banner` helper alongside `Banner`, so
# every project page gets the same tab chrome regardless of which
# page is active -- no caller renders `AdminSubtabs`/
# `ObservationSubtabs` itself, and no caller needs to pass
# `current_tab:` for a page these hashes cover (see `#current_tab`).
module Views::Controllers::Projects
  class ProjectNavs < Views::Base
    prop :project, ::Project
    prop :user, _Nilable(User), default: nil
    prop :current_tab, _Nilable(String), default: nil

    # Every controller that renders the admin sub-tabs below the main
    # tabs (see Tab::Project::AdminSubtabs), keyed to the sub-tab it
    # lands on. The two Field Slips paths are handled separately --
    # see `#show_admin_subtabs?`/`#show_observation_subtabs?` -- since
    # which sub-tab bar they get depends on whether the viewer is a
    # project admin, not on the controller_path alone.
    ADMIN_SUBTAB_CONTROLLERS = {
      "projects/admin" => "details",
      "projects/members" => "members",
      "projects/aliases" => "aliases",
      "projects/external_sites" => "external_sites"
    }.freeze

    # Every controller that renders the member-facing observation
    # sub-tabs below the main tabs (see Tab::Project::ObservationSubtabs).
    OBSERVATION_SUBTAB_CONTROLLERS = {
      "observations" => "observations",
      "observations/maps" => "map",
      "images" => "images",
      "observations/downloads" => "download",
      "projects/violations" => "violations"
    }.freeze

    FIELD_SLIPS_CONTROLLERS = ["field_slips", "projects/field_slips"].freeze

    def view_template
      render_project_tabs
      render_subtabs
    end

    private

    def render_project_tabs
      tab_margin_class = no_tab_bottom_margin? ? "mt-3" : "my-3"

      NavTabs(
        id: "project_tabs", class: tab_margin_class,
        current: current_tab,
        tabs: ::Tab::Project::Banner.new(
          project: @project, user: @user
        )
      )
    end

    # The main tab bar's active tab. A page covered by one of the
    # sub-tab hashes always highlights "admin"/"observations" there,
    # regardless of what the controller itself passed as
    # `current_tab:` -- derived here instead of via each controller's
    # own `active_project_tab` override.
    def current_tab
      if show_admin_subtabs?
        "admin"
      elsif show_observation_subtabs?
        "observations"
      else
        @current_tab
      end
    end

    def render_subtabs
      if show_admin_subtabs?
        render(AdminSubtabs.new(
                 project: @project, current_subtab: current_admin_subtab
               ))
      elsif show_observation_subtabs?
        render(ObservationSubtabs.new(
                 project: @project,
                 current_subtab: current_observation_subtab
               ))
      end
    end

    def show_admin_subtabs?
      ADMIN_SUBTAB_CONTROLLERS.key?(controller.controller_path) ||
        (field_slips_page? && @project.is_admin?(@user))
    end

    def show_observation_subtabs?
      OBSERVATION_SUBTAB_CONTROLLERS.key?(controller.controller_path) ||
        (field_slips_page? && !@project.is_admin?(@user))
    end

    def field_slips_page?
      FIELD_SLIPS_CONTROLLERS.include?(controller.controller_path)
    end

    def current_admin_subtab
      return "field_slips" if field_slips_page?

      ADMIN_SUBTAB_CONTROLLERS[controller.controller_path]
    end

    def current_observation_subtab
      return "field_slips" if field_slips_page?

      OBSERVATION_SUBTAB_CONTROLLERS[controller.controller_path]
    end

    def no_tab_bottom_margin?
      project_page? || show_admin_subtabs? || show_observation_subtabs?
    end

    def project_page?
      controller.controller_name == "projects" &&
        controller.action_name == "show"
    end
  end
end

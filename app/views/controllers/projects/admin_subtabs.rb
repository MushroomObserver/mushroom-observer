# frozen_string_literal: true

# Sub-tab navigation for the project Admin tab. Renders Details /
# N Members / N Aliases / Field Slips, plus External Sites for a site
# admin, as Bootstrap tabs below the main tab bar. The current
# sub-tab is highlighted; the main Admin tab stays selected via the
# parent banner's current_tab.
#
# Shared across the projects admin sub-controllers (admin, members,
# aliases, field_slips, external_sites). Lives in
# `Views::Controllers::Projects` at the cluster root rather than
# nested under a sub-controller's directory.
module Views::Controllers::Projects
  class AdminSubtabs < Views::Base
    prop :project, ::Project
    prop :current_subtab,
         _Union("details", "members", "aliases", "field_slips",
                "external_sites")

    def view_template
      NavTabs(
        id: "project_admin_subtabs", class: "pl-3 pl-lg-5 mt-2 mb-3",
        current: @current_subtab,
        tabs: ::Tab::Project::AdminSubtabs.new(project: @project,
                                               site_admin: in_admin_mode?)
      )
    end
  end
end

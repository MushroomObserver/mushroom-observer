# frozen_string_literal: true

# Sub-tab navigation for the project Admin tab. Renders Details /
# N Members / N Aliases as Bootstrap tabs, indented under the main
# tab bar. The current sub-tab is highlighted; the main Admin tab
# stays selected via the parent banner's current_tab.
#
# Shared across the projects admin sub-controllers (admin, members,
# aliases). Lives in `Views::Controllers::Projects` at the cluster
# root rather than nested under a sub-controller's directory.
module Views::Controllers::Projects
  class AdminSubtabs < Views::Base
    def initialize(project:, current_subtab:)
      super()
      @project = project
      @current_subtab = current_subtab
    end

    def view_template
      div(class: "row") do
        Column(xs: 12, class: "pl-4 mt-2 mb-3",
               id: "project_admin_subtabs") do
          NavTabs(
            current: @current_subtab,
            tabs: ::Tab::Project::AdminSubtabs.new(project: @project)
          )
        end
      end
    end
  end
end

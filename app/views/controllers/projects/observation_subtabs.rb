# frozen_string_literal: true

module Views::Controllers::Projects
  class ObservationSubtabs < Views::Base
    prop :project, ::Project
    prop :current_subtab,
         _Union("observations", "map", "images", "download",
                "field_slips", "violations")

    def view_template
      NavTabs(
        id: "project_observation_subtabs", class: "pl-3 pl-lg-5 mt-2 mb-3",
        current: @current_subtab,
        tabs: ::Tab::Project::ObservationSubtabs.new(
          project: @project, query: current_query, controller: controller
        )
      )
    end
  end
end

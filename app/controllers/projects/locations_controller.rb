# frozen_string_literal: true

module Projects
  class LocationsController < ApplicationController
    include Projects::LocationGrouping

    before_action :login_required

    def index
      return unless find_project!

      @grouped_data, @ungrouped_locations =
        build_grouped_locations(@project)
      @obs_counts = observation_counts(@project)
    end

    private

    def find_project!
      @project = find_or_goto_index(
        Project, params[:project_id].to_s
      )
    end
  end
end

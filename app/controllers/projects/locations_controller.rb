# frozen_string_literal: true

#  ==== Manage Project Locations
#  index::
#
#  In the future may add ability to create aliases

module Projects
  # Index for project locations
  class LocationsController < ApplicationController
    before_action :login_required

    def index
      return unless find_project!

      locs = @project.locations.distinct
      @locations = if User.current_location_format == "scientific"
                     locs.order(:scientific_name)
                   else
                     locs.order(:name)
                   end
    end

    private

    def find_project!
      @project = find_or_goto_index(Project, params[:project_id].to_s)
    end
  end
end

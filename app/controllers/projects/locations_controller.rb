# frozen_string_literal: true

module Projects
  class LocationsController < ApplicationController
    before_action :login_required

    def index
      return unless find_project!

      @locations = merged_locations
    end

    private

    def find_project!
      @project = find_or_goto_index(Project, params[:project_id].to_s)
    end

    # Merge observation-derived locations with target locations,
    # removing duplicates.
    def merged_locations
      obs_locs = @project.locations.distinct
      target_locs = @project.target_locations
      all_locs = (obs_locs.to_a + target_locs.to_a).uniq(&:id)
      sort_locations(all_locs)
    end

    def sort_locations(locs)
      locs.sort_by(&:scientific_name)
    end
  end
end

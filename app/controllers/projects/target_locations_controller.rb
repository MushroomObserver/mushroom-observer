# frozen_string_literal: true

module Projects
  class TargetLocationsController < ApplicationController
    include Projects::LocationGrouping

    before_action :login_required
    before_action :set_project
    before_action :require_admin

    def create
      locations = parse_locations_from_params
      if locations.any?
        add_locations(locations)
      else
        flash_error(:project_target_location_not_found.t)
      end
      respond_to do |format|
        format.turbo_stream { render_locations_update }
        format.html { redirect_to_locations }
      end
    end

    def destroy
      location = Location.safe_find(params[:id])
      if location
        @project.remove_target_location(location)
        flash_notice(
          :project_target_location_removed.t(
            name: location.display_name
          )
        )
      else
        flash_error(:project_target_location_not_found.t)
      end
      respond_to do |format|
        format.turbo_stream { render_locations_update }
        format.html { redirect_to_locations }
      end
    end

    private

    def set_project
      @project = find_or_goto_index(
        Project, params[:project_id]
      )
    end

    def require_admin
      return if @project&.is_admin?(@user)

      flash_error(:permission_denied.t)
      redirect_to_locations
    end

    def redirect_to_locations
      redirect_to(
        project_locations_path(project_id: @project.id)
      )
    end

    # Submitted under the `project_target_locations_add` namespace by
    # Components::ProjectTargetLocationsWidget (Pattern B form).
    def parse_locations_from_params
      raw = params.dig(:project_target_locations_add, :locations).to_s
      raw.split("\n").filter_map do |entry|
        cleaned = entry.strip
        next if cleaned.blank?

        Location.find_by(name: cleaned) ||
          Location.find_by(scientific_name: cleaned)
      end
    end

    def add_locations(locations)
      added = locations.select do |loc|
        next false if @project.target_locations.include?(loc)

        @project.add_target_location(loc)
        true
      end
      return unless added.any?

      list = added.map(&:display_name).join(", ")
      flash_notice(
        :project_target_locations_added.t(names: list)
      )
    end

    def render_locations_update
      grouped, ungrouped = build_grouped_locations(@project)
      counts = observation_counts(@project)
      render(
        partial: "projects/target_locations/locations_update",
        locals: { project: @project, user: @user,
                  grouped_data: grouped,
                  ungrouped_locations: ungrouped,
                  obs_counts: counts }
      )
    end
  end
end

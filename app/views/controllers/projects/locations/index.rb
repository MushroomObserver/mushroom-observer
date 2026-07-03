# frozen_string_literal: true

# Action template for the Project Locations index.
#
# Renders the project banner + (admins only) the target-location
# form, then the grouped-locations table.
#
# `Projects::LocationsController#render_locations_index_view` renders
# this class directly with explicit props.
module Views::Controllers::Projects::Locations
  class Index < Views::FullPageBase
    prop :project, ::Project
    # `[{ target: Location, sub_locations: [Location, ...] }, ...]`
    # (or `[]` when the project has no target locations).
    # Built by `Projects::LocationGrouping#build_grouped_locations`.
    prop :grouped_data, _Array(_Hash(Symbol, _Any))
    prop :ungrouped_locations, _Array(::Location)
    # `location_id => observation_count` from
    # `Projects::LocationGrouping#observation_counts`.
    prop :obs_counts, _Hash(Integer, Integer)
    prop :user, _Nilable(::User), default: nil

    def view_template
      container_class(:wide)
      add_project_banner(@project)

      render_target_location_form if @project.is_admin?(@user)
      render_table
    end

    private

    def render_target_location_form
      render(Views::Controllers::Projects::TargetLocations::Form.new(
               project: @project
             ))
    end

    def render_table
      render(Views::Controllers::Projects::Locations::Tables.new(
               project: @project,
               grouped_data: @grouped_data,
               ungrouped_locations: @ungrouped_locations,
               obs_counts: @obs_counts,
               user: @user
             ))
    end
  end
end

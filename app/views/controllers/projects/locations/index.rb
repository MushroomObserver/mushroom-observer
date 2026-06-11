# frozen_string_literal: true

# Action template for the Project Locations index. Replaces
# `app/views/controllers/projects/locations/index.html.erb`.
#
# Renders the project banner + (admins only) the target-location
# form, then the grouped-locations table.
#
# `Projects::LocationsController#render_locations_index_view` renders
# this class directly with explicit props.
module Views::Controllers::Projects::Locations
  class Index < Views::Base
    prop :project, ::Project
    prop :grouped_data, _Any
    prop :ungrouped_locations, _Any
    prop :obs_counts, _Any
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
      render(Views::Controllers::Projects::Locations::Table.new(
               project: @project,
               grouped_data: @grouped_data,
               ungrouped_locations: @ungrouped_locations,
               obs_counts: @obs_counts,
               user: @user
             ))
    end
  end
end

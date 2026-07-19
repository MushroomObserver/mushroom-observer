# frozen_string_literal: true

class Tab::Project::Locations < Tab::Base
  def initialize(project:)
    super()
    @project = project
  end

  def title
    "#{@project.location_count} #{:locations.ti}"
  end

  def path
    project_locations_path(project_id: @project.id)
  end

  def alt_title
    "locations"
  end
end

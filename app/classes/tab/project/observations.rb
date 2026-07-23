# frozen_string_literal: true

class Tab::Project::Observations < Tab::Base
  def initialize(project:)
    super()
    @project = project
  end

  def title
    "#{@project.visible_observations.count} #{:observations.ti}"
  end

  def path
    observations_path(project: @project)
  end

  def alt_title
    "observations"
  end
end

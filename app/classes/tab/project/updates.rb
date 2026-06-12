# frozen_string_literal: true

class Tab::Project::Updates < Tab::Base
  def initialize(project:)
    super()
    @project = project
  end

  def title
    "#{@project.new_candidate_observations_count} " \
      "#{:project_updates_title.l}"
  end

  def path
    project_updates_path(project_id: @project.id)
  end

  def alt_title
    "updates"
  end
end

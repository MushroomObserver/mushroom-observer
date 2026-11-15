# frozen_string_literal: true

class Tab::Project::Names < Tab::Base
  def initialize(project:)
    super()
    @project = project
  end

  def title
    "#{count_text} #{:names.ti}"
  end

  def path
    checklist_path(project_id: @project.id)
  end

  def alt_title
    "checklists"
  end

  private

  def count_text
    return checklist.num_taxa.to_s unless checklist.num_targets.positive?

    "#{checklist.num_targets_observed}/#{checklist.num_targets}"
  end

  def checklist
    @checklist ||= Checklist::ForProject.new(@project)
  end
end

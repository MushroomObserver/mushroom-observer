# frozen_string_literal: true

# Member-facing observation sub-tab linking to the project's
# constraint-violations page -- the list of the project's
# observations that fail one or more of its constraints. Only
# included (by the Collection) when the project has constraints set.
class Tab::Project::ObservationViolations < Tab::Base
  def initialize(project:)
    super()
    @project = project
  end

  def title
    "#{@project.count_violations} #{:constraint_violations.ti}"
  end

  def path
    project_violations_path(@project.id)
  end

  def alt_title
    "violations"
  end
end

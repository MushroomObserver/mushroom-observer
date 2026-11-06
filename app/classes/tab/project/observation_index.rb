# frozen_string_literal: true

# Member-facing observation sub-tab: back to the project's
# observations index. Distinct from the main-tab
# `Tab::Project::Observations` (same path) because that tab's title
# carries an observation count -- this one just reads "Observations",
# matching the other sub-tabs' plain labels.
class Tab::Project::ObservationIndex < Tab::Base
  def initialize(project:)
    super()
    @project = project
  end

  def title
    :observations.ti
  end

  def path
    observations_path(project: @project, by: "thumbnail_quality")
  end

  def alt_title
    "observations"
  end
end

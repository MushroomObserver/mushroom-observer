# frozen_string_literal: true

class Tab::Project::Observations < Tab::Base
  def initialize(project:)
    super()
    @project = project
  end

  def title
    "#{@project.visible_observations.count} #{:observations.ti}"
  end

  # `by: "thumbnail_quality"` is explicit here, not a default_order on
  # the `projects` query_attr -- keeps the ordering choice scoped to
  # this one link instead of leaking into other `projects:` filters
  # (e.g. subquery composition; see Query::Observations).
  def path
    observations_path(project: @project, by: "thumbnail_quality")
  end

  def alt_title
    "observations"
  end
end

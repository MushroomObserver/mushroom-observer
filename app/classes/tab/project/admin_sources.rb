# frozen_string_literal: true

# Admin sub-tab linking to the project's external source configuration
# -- where its observations may come from on iNaturalist, and what MO
# may do about them (#5416).
class Tab::Project::AdminSources < Tab::Base
  def initialize(project:)
    super()
    @project = project
  end

  def title
    :project_sources_tab.l
  end

  def path
    project_external_sources_path(project_id: @project.id)
  end

  def alt_title
    "sources"
  end
end

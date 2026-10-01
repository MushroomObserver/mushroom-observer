# frozen_string_literal: true

# Admin sub-tab linking to the project's external sites -- what it
# already holds from each, and, where MO can act, where its observations
# may come from and what MO may do about them (#5416). Site admins only
# for now; see Tab::Project::AdminSubtabs.
class Tab::Project::AdminExternalSites < Tab::Base
  def initialize(project:)
    super()
    @project = project
  end

  def title
    :project_sites_tab.l
  end

  def path
    project_external_sites_path(project_id: @project.id)
  end

  def alt_title
    "external_sites"
  end
end

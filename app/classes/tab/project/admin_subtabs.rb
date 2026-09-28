# frozen_string_literal: true

# The sub-tab strip rendered under the project Admin tab (Details /
# Members / Aliases / Field Slips), plus External Sites for a site admin
# -- configuring what MO pulls from iNaturalist is theirs to do until
# the cycle has run for a while (#5416).
class Tab::Project::AdminSubtabs < Tab::Collection
  def initialize(project:, site_admin: false)
    super()
    @project = project
    @site_admin = site_admin
  end

  private

  def tabs
    [
      Tab::Project::AdminDetails.new(project: @project),
      Tab::Project::AdminMembers.new(project: @project),
      Tab::Project::AdminAliases.new(project: @project),
      Tab::Project::AdminFieldSlips.new(project: @project),
      external_sites_tab
    ].compact
  end

  def external_sites_tab
    return nil unless @site_admin

    Tab::Project::AdminExternalSites.new(project: @project)
  end
end

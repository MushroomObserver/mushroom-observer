# frozen_string_literal: true

# The sub-tab strip rendered under the project Admin tab (Details /
# Members / Aliases / Field Slips). Always all four; no conditional
# inclusion.
class Tab::Project::AdminSubtabs < Tab::Collection
  def initialize(project:)
    super()
    @project = project
  end

  private

  def tabs
    [
      Tab::Project::AdminDetails.new(project: @project),
      Tab::Project::AdminMembers.new(project: @project),
      Tab::Project::AdminAliases.new(project: @project),
      Tab::Project::AdminFieldSlips.new(project: @project)
    ]
  end
end

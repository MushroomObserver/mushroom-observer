# frozen_string_literal: true

# Action-nav for the "Change member status" project page. Three
# tabs (cancel-to-projects-index + cancel-and-show project +
# edit-project) when the caller passes `permission: true`; empty
# tab list otherwise so the context-nav is hidden entirely.
# Controllers gate access to this page upstream, so the
# no-permission branch is defensive.
class Tab::Project::Members::FormEdit < Tab::Collection
  def initialize(project:, permission:)
    super()
    @project = project
    @permission = permission
  end

  private

  def tabs
    return [] unless @permission

    [
      Tab::Project::Index.new,
      Tab::Object::Return.new(object: @project),
      Tab::Project::ChangeMemberStatus.new(project: @project)
    ]
  end
end

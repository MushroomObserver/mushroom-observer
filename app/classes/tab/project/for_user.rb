# frozen_string_literal: true

# "Projects you belong to" sidebar/action-nav link for a specific
# user — filters the projects index to that user's memberships.
class Tab::Project::ForUser < Tab::Base
  def initialize(user:)
    super()
    @user = user
  end

  def title
    :app_your_projects.l
  end

  def path
    projects_path(member: @user.id)
  end
end

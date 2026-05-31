# frozen_string_literal: true

class Tab::Project::AdminMembers < Tab::Base
  def initialize(project:)
    super()
    @project = project
  end

  def title
    "#{@project.user_group.users.count} #{:MEMBERS.l}"
  end

  def path
    project_members_path(@project.id)
  end

  def alt_title
    "members"
  end
end

# frozen_string_literal: true

class UpdateProjectMembers < ActiveRecord::Migration[6.1]
  def up
    Project.find_each do |proj|
      proj.admin_group.users.find_each do |user|
        check_project_member(proj, user, true)
      end
    end
  end

  def down; end

  def check_project_member(project, user, trusted)
    member = ProjectMember.find_by(project: project, user: user)
    return if member

    puts("Add ProjectMember #{user.login} for #{project.title} as #{trusted}")
    ProjectMember.create!(project:, user:, trusted:)
  end
end

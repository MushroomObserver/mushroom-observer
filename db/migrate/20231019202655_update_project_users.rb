# frozen_string_literal: true

class UpdateProjectUsers < ActiveRecord::Migration[6.1]
  def up
    Project.find_each do |project|
      project.user_group.users.each do |user|
        ProjectMember.create(project:, user:,
                             trusted: project.user_id == user.id)
      end
    end
  end

  def down; end
end

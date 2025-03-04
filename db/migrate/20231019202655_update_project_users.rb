# frozen_string_literal: true

class UpdateProjectUsers < ActiveRecord::Migration[6.1]
  def up
    Project.find_each do |project|
      project.user_group.users.each do |user|
        trusted = (project.user_id == user.id) || !project.open_membership
        ProjectMember.create(project:, user:, trusted:)
      end
    end
  end

  def down; end
end

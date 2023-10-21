# frozen_string_literal: true

class UpdateProjectUsers < ActiveRecord::Migration[6.1]
  def up
    Project.find_each do |project|
      admins = project.admin_group.users
      admins.each do |user|
        ProjectMember.create(project:, user:, admin: true)
      end
      project.user_group.users.each do |user|
        unless admins.include?(user)
          ProjectMember.create(project:, user:, admin: false)
        end
      end
    end
  end

  def down; end
end

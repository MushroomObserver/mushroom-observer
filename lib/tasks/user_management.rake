# frozen_string_literal: true

# lib/tasks/user_management.rake

namespace :user do
  desc "Add or update a user from the command line"
  task add: :environment do
    service = UserManagementService.new
    result = service.create_or_update_user?
    exit 1 unless result
  end

  desc "List all users"
  task list: :environment do
    service = UserManagementService.new
    service.list_users
  end

  desc "Verify a user by login or email"
  task verify: :environment do
    service = UserManagementService.new
    result = service.verify_user?
    exit 1 unless result
  end
end

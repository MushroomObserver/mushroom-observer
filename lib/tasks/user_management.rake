# frozen_string_literal: true

# lib/tasks/user_management.rake

namespace :user do
  desc "Add a user from the command line"
  task add: :environment do
    config_logger
    service = UserManagementService.new
    result = service.create_user?
    exit 1 unless result
  end

  desc "List all users"
  task list: :environment do
    config_logger
    service = UserManagementService.new
    service.list_users
  end

  desc "Verify a user by login or email"
  task verify: :environment do
    config_logger
    service = UserManagementService.new
    result = service.verify_user?
    exit 1 unless result
  end

  def config_logger
    STDOUT.sync = true
    Rails.logger = Logger.new(STDOUT, level: Logger::DEBUG, 
                              formatter: proc { |s,d,p,m| m })
  end
end

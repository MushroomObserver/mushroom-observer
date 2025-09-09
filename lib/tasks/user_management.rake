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

  desc "Verify a user by login or email"
  task verify: :environment do
    config_logger
    service = UserManagementService.new
    result = service.verify_user?
    exit 1 unless result
  end

  def config_logger
    $stdout.sync = true
    Rails.logger = Logger.new($stdout, level: Logger::DEBUG,
                                       formatter: proc { |_s, _d, _p, m| m })
  end
end

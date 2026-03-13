# frozen_string_literal: true

class UserManagementService::StdoutOutputHandler
  delegate :print, to: :$stdout

  def puts(str)
    Rails.logger.debug(str)
    Rails.logger.debug("\n")
  end

  def print_header(title)
    Rails.logger.debug { "#{:user_management_header.t(title:)}\n" }
  end
end

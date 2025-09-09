# frozen_string_literal: true

class UserManagementService::StdinInputHandler
  def get_input(prompt)
    Rails.logger.debug { "#{prompt}: " }
    $stdin.gets.chomp.strip
  end

  def get_password(prompt)
    require("io/console")
    Rails.logger.debug { "#{prompt}: " }
    password = $stdin.noecho(&:gets).chomp
    Rails.logger.debug("\n")
    password
  end
end

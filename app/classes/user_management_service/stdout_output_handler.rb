# frozen_string_literal: true

class UserManagementService::StdoutOutputHandler
  delegate :puts, to: :$stdout

  delegate :print, to: :$stdout

  def printf(format, *)
    $stdout.printf(format, *)
  end

  def print_header(title)
    puts("=== #{title} ===") # rubocop:disable Rails/Output
    puts("") # rubocop:disable Rails/Output
    # Rails.logger.debug { "=== #{title} ===" }
    # Rails.logger.debug("")
  end
end

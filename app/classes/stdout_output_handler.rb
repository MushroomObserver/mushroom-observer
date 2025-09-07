# frozen_string_literal: true

# app/services/stdout_output_handler.rb

class StdoutOutputHandler
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

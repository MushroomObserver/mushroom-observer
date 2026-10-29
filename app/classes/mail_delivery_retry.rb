# frozen_string_literal: true

require("net/smtp")

# Which mail delivery failures are worth retrying, and when. Used by the
# MailDeliveryJob handler in config/initializers/mail_delivery_error_logging.rb.
module MailDeliveryRetry
  # Waits before the 2nd, 3rd, ... attempts; 5 attempts in all.
  WAITS = [1.minute, 5.minutes, 30.minutes, 2.hours].freeze

  NETWORK_ERRORS = [
    Net::OpenTimeout, Net::ReadTimeout, EOFError,
    Errno::ECONNRESET, Errno::ECONNREFUSED, Errno::ETIMEDOUT
  ].freeze

  module_function

  # The wait before retrying after `error` on attempt `executions`, or nil
  # when the error is permanent or the attempts are used up.
  def wait_for(error, executions)
    return nil unless transient?(error)

    WAITS[executions - 1]
  end

  # SMTP 4xx replies are temporary by definition. net-smtp raises some of
  # them as SMTPAuthenticationError (Gmail's 454), so read the reply code
  # rather than the class; a 535 bad password is permanent.
  def transient?(error)
    return true if NETWORK_ERRORS.any? { |klass| error.is_a?(klass) }

    error.is_a?(Net::SMTPError) && error.message.start_with?("4")
  end
end

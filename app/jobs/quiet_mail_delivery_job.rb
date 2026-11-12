# frozen_string_literal: true

# Mail delivery that keeps its job arguments out of the Rails log.
# ActiveJob logs every argument it is handed, so a mailer carrying a
# cleartext credential leaves that credential in production.log. Who
# the mail went to is still recorded, by
# `ApplicationMailer#debug_log`.
class QuietMailDeliveryJob < ActionMailer::MailDeliveryJob
  self.log_arguments = false
end

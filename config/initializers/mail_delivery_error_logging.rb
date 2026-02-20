# frozen_string_literal: true

# Log email delivery failures to email-debug.log, then re-raise
# so Solid Queue can track the failure. This ensures we notice
# delivery errors instead of silently swallowing them.
Rails.application.config.after_initialize do
  ActionMailer::MailDeliveryJob.rescue_from(
    StandardError
  ) do |exception|
    mailer, action = arguments[0..1]
    args = arguments[3..] || []
    msg = "DELIVERY FAILED #{mailer}##{action}"
    msg << " args=#{args.inspect}" if args.any?
    msg << " error=#{exception.class}: " \
           "#{exception.message}"
    Rails.root.join("log/email-debug.log").
      open("a:utf-8") do |fh|
        fh.puts("#{Time.zone.now} #{msg}")
      end
    raise(exception)
  end
end

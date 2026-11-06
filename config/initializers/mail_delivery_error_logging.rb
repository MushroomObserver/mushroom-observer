# frozen_string_literal: true

# Retry temporary delivery failures (see MailDeliveryRetry); log the rest
# to email-debug.log and re-raise so Solid Queue records the failure.
Rails.application.config.after_initialize do
  ActionMailer::MailDeliveryJob.rescue_from(
    StandardError
  ) do |exception|
    mailer, action = arguments[0..1]
    params = arguments[3] || {}
    wait = MailDeliveryRetry.wait_for(exception, executions)
    msg = if wait
            "DELIVERY RETRY in #{wait.inspect} #{mailer}##{action}"
          else
            "DELIVERY FAILED #{mailer}##{action}"
          end
    msg << " params=#{params.inspect}" if params.present?
    msg << " error=#{exception.class}: " \
           "#{exception.message}"
    MO.email_debug_log_path.open("a:utf-8") do |fh|
      fh.puts("#{Time.zone.now} #{msg}")
    end
    wait ? retry_job(wait: wait) : raise(exception)
  end
end

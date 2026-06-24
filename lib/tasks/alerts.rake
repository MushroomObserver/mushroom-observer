# frozen_string_literal: true

namespace :alerts do
  desc "Send a test exception alert to verify exception_notification -> Slack"
  task test: :environment do
    unless alerts_active?
      puts("Alerting is gated off in this environment — nothing sent. Use " \
           "`NOTIFY_EXCEPTIONS=1 bin/rails alerts:test` (with the webhook in " \
           "credentials), or run in production.")
      next
    end

    ExceptionNotifier.notify_exception(
      RuntimeError.new("MO Alerts test (#{Rails.env}) at #{Time.zone.now}")
    )
    puts("Sent test alert via ExceptionNotifier — check the #alerts channel.")
  end

  def alerts_active?
    webhook = Rails.application.credentials.slack_alerts_webhook_url
    webhook.present? && !Rails.env.test? &&
      (Rails.env.production? || ENV["NOTIFY_EXCEPTIONS"] == "1")
  end
end

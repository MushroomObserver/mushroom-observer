# frozen_string_literal: true

def alerts_active?
  webhook = ENV["SLACK_ALERTS_WEBHOOK_URL"].presence ||
            Rails.application.credentials.slack_alerts_webhook_url
  webhook.present? && !Rails.env.test? &&
    (Rails.env.production? || ENV["NOTIFY_EXCEPTIONS"] == "1")
end

def warn_alerts_gated_off
  puts("Alerting is gated off here — nothing to do (a worker couldn't " \
       "notify, and the silence would look like a missing notifier). Run " \
       "in production, or locally with `NOTIFY_EXCEPTIONS=1 " \
       "SLACK_ALERTS_WEBHOOK_URL=<url>`.")
end

namespace :alerts do
  desc "Send a test exception alert to verify exception_notification -> Slack"
  task test: :environment do
    next warn_alerts_gated_off unless alerts_active?

    ExceptionNotifier.notify_exception(
      RuntimeError.new("MO Alerts test (#{Rails.env}) at #{Time.zone.now}")
    )
    puts("Sent test alert via ExceptionNotifier — check the #alerts channel.")
  end

  desc "Enqueue AlertTestJob so a Solid Queue worker exercises the " \
       "job -> #alerts path end to end (modes: alert, raise, repeat)"
  task :test_job, [:mode] => :environment do |_t, args|
    next warn_alerts_gated_off unless alerts_active?

    mode = args[:mode] || "alert"
    AlertTestJob.perform_later(mode: mode)
    puts("Enqueued AlertTestJob (mode=#{mode}). A worker on :maintenance " \
         "should run it shortly — check #alerts. For de-dup testing, run " \
         "`alerts:test_job[repeat]` several times in quick succession.")
  end
end

# frozen_string_literal: true

def alerts_active?
  webhook = ENV["SLACK_ALERTS_WEBHOOK_URL"].presence ||
            Rails.application.credentials.slack_alerts_webhook_url
  webhook.present? && !Rails.env.test? &&
    (Rails.env.production? || ENV["NOTIFY_EXCEPTIONS"] == "1")
end

namespace :alerts do
  desc "Send a test exception alert to verify exception_notification -> Slack"
  task test: :environment do
    unless alerts_active?
      puts("Alerting is gated off here — nothing sent. Locally use " \
           "`NOTIFY_EXCEPTIONS=1 SLACK_ALERTS_WEBHOOK_URL=<url> bin/rails " \
           "alerts:test`, or run in production.")
      next
    end

    ExceptionNotifier.notify_exception(
      RuntimeError.new("MO Alerts test (#{Rails.env}) at #{Time.zone.now}")
    )
    puts("Sent test alert via ExceptionNotifier — check the #alerts channel.")
  end

  desc "Enqueue AlertTestJob so a Solid Queue worker exercises the " \
       "job -> #alerts path end to end (modes: alert, raise, repeat)"
  task :test_job, [:mode] => :environment do |_t, args|
    mode = args[:mode] || "alert"
    AlertTestJob.perform_later(mode: mode)
    puts("Enqueued AlertTestJob (mode=#{mode}). A worker on the " \
         ":maintenance queue should run it shortly — check #alerts. For " \
         "de-dup testing, run `alerts:test_job[repeat]` several times in " \
         "quick succession.")
  end
end

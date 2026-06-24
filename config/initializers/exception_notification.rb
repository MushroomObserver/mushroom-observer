# frozen_string_literal: true

# Real-time exception alerts to Slack (#alerts) via the exception_notification
# gem. Complements -- does not replace -- script/parse_log's cron email digest.
#
# Needs the Slack incoming-webhook URL. In production it lives in the
# production credentials (edit on the server, where the prod key is):
#   RAILS_ENV=production bin/rails credentials:edit
#     slack_alerts_webhook_url: https://hooks.slack.com/services/T.../B.../...
#
# Active in production; also activatable anywhere except tests with
# NOTIFY_EXCEPTIONS=1. Since the credential is production-only, a local
# pre-deploy check passes the webhook via env var instead:
#   NOTIFY_EXCEPTIONS=1 SLACK_ALERTS_WEBHOOK_URL=<url> bin/rails alerts:test
# (see lib/tasks/alerts.rake).
#
# This middleware reports web-request exceptions; background-job (SolidQueue /
# ActiveJob) failures are reported from ApplicationJob via the same notifier.
webhook = ENV["SLACK_ALERTS_WEBHOOK_URL"].presence ||
          Rails.application.credentials.slack_alerts_webhook_url
enabled = webhook.present? && !Rails.env.test? &&
          (Rails.env.production? || ENV["NOTIFY_EXCEPTIONS"] == "1")

if enabled
  Rails.application.config.middleware.use(
    ExceptionNotification::Rack,
    # Skip the routine noise also excluded by script/parse_log.
    ignore_exceptions: %w[
      ActiveRecord::RecordNotFound
      AbstractController::ActionNotFound
      ActionController::RoutingError
      ActionController::InvalidAuthenticityToken
      ActionController::UnknownFormat
      ActionController::BadRequest
      Rack::QueryParser::InvalidParameterError
    ],
    # Collapse a burst of the same error into one alert.
    error_grouping: true,
    slack: {
      webhook_url: webhook,
      channel: "#alerts",
      additional_parameters: { mrkdwn: true }
    }
  )
end

# frozen_string_literal: true

# Real-time exception alerts to Slack (#alerts) via the exception_notification
# gem. Complements -- does not replace -- script/parse_log's cron email digest.
#
# Needs the Slack incoming-webhook URL in credentials:
#   bin/rails credentials:edit
#     slack_alerts_webhook_url: https://hooks.slack.com/services/T.../B.../...
#
# Active in production; also activatable anywhere except tests with
# NOTIFY_EXCEPTIONS=1, so you can verify the wiring pre-deploy (credentials are
# shared across envs, so the production-only default keeps dev/CI quiet). Verify
# with `NOTIFY_EXCEPTIONS=1 bin/rails alerts:test` (see lib/tasks/alerts.rake).
#
# This middleware reports web-request exceptions; background-job (SolidQueue /
# ActiveJob) failures are reported from ApplicationJob via the same notifier.
webhook = Rails.application.credentials.slack_alerts_webhook_url
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

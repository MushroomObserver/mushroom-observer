# frozen_string_literal: true

# Real-time exception alerts to Slack (#alerts) via the exception_notification
# gem. Complements -- does not replace -- script/parse_log's cron email digest.
#
# Activated only in production and only when the Slack incoming-webhook URL is
# present in credentials, so dev / test / CI stay silent. Add the webhook with:
#   bin/rails credentials:edit
#     slack_alerts_webhook_url: https://hooks.slack.com/services/T.../B.../...
#
# This middleware reports web-request exceptions; background-job (SolidQueue /
# ActiveJob) failures are reported from ApplicationJob via the same notifier.
webhook = Rails.application.credentials.slack_alerts_webhook_url

if Rails.env.production? && webhook.present?
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

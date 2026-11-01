# frozen_string_literal: true

# Exception alerts to Slack (#alerts) via the exception_notification
# gem, complementing script/parse_log's cron email digest. Needs the
# Slack incoming-webhook URL from production credentials; active in
# production, or anywhere except tests with NOTIFY_EXCEPTIONS=1
# (local pre-deploy check passes the webhook via
# SLACK_ALERTS_WEBHOOK_URL instead -- see lib/tasks/alerts.rake).
# This middleware reports web-request exceptions; background-job
# failures are reported from ApplicationJob via the same notifier.
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
      ActionDispatch::Http::MimeNegotiation::InvalidType
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

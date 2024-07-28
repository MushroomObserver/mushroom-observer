# frozen_string_literal: true

MushroomObserver::Application.configure do
  # Settings specified here will take precedence over those in
  # config/application.rb.

  # ----------------------------
  #  MO configuration.
  # ----------------------------
  config.domain      = "localhost"
  config.http_domain = "http://localhost:3000"

  # List of alternate server domains.
  # We redirect from each of these to the real one.
  config.bad_domains = ["localhost.localdomain:3000"]

  # Code appended to ids to make "sync_id".  Must start with letter.
  config.server_code = "XX"

  # Turn off email.
  config.queue_email = false

  # Tell ActionMailer not to deliver emails to the real world.
  # The :file delivery method accumulates sent emails in the
  # ../mail directory.  (This is a feature I added. -JPH 20080213)
  config.action_mailer.delivery_method = :file

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false
  # config.action_mailer.perform_caching = false

  config.action_mailer.smtp_settings = {
    address: "localhost",
    port: 25,
    domain: "localhost"
  }

  # Use this to actually send some Gmail via SMTP-Relay in development,
  # provided you have the credentials in credentials.yml.enc
  #
  # config.queue_email = true
  # config.action_mailer.delivery_method = :smtp
  # config.action_mailer.perform_deliveries = true
  # config.action_mailer.raise_delivery_errors = true
  # config.action_mailer.smtp_settings =
  #   Rails.application.credentials.gmail_smtp_settings_webmaster

  config.image_precedence = { default: [:local, :mycolab] }
  config.image_fallback_source = :mycolab

  config.robots_dot_text_file = "#{config.root}/public/robots.txt"

  # ----------------------------
  #  Rails configuration.
  # ----------------------------
  # In the development environment your application's code is reloaded any time
  # it changes. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  # Replaces config.cache_classes = false
  config.enable_reloading = true

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable server timing.
  config.server_timing = true

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.action_controller.perform_caching = true
    # debugging: log fragment reads/writes
    # (it will show [cache hit] even if set to false)
    config.action_controller.enable_fragment_cache_logging = true

    config.cache_store = :memory_store # :mem_cache_store via application.rb
    config.public_file_server.headers = {
      "Cache-Control" => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false
  end

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log
  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise
  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Allow YAML deserializer to deserialize symbols.
  # https://groups.google.com/g/rubyonrails-security/c/MmFO3LYQE8U?pli=1
  config.active_record.yaml_column_permitted_classes = [Symbol]

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Highlight code that enqueued background job in logs.
  config.active_job.verbose_enqueue_logs = true

  # New 7.1 logging uses BroadcastLogger. Not using TaggedLogging yet.
  # Enable this to format dev logs like the production logs.
  # loggers = [
  #   $stdout
  # ].map do |output|
  #   ActiveSupport::Logger.new(output).
  #     tap { |logger| logger.formatter = Logger::Formatter.new }
  #   # .then { |logger| ActiveSupport::TaggedLogging.new(logger) }
  # end
  # config.logger = ActiveSupport::BroadcastLogger.new(*loggers)

  # Serve assets in rails.
  config.public_file_server.enabled = true

  # Compile asset files, but don't combine, compress, or add digests to names.
  config.assets.compile = true

  # Recommended by Rails team to keep assets digest true in dev mode.
  # As of 2023-09-06, Stimulus-loading.js will 404 if false.
  # https://github.com/hotwired/stimulus-rails/issues/108#issuecomment-1680804528
  config.assets.digest = true

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = false
  config.assets.logger = false

  # Suppress logger output for asset requests.
  config.assets.quiet = false

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Raise error when a before_action's only/except options reference
  # missing actions.
  config.action_controller.raise_on_missing_callback_actions = true

  # Enable web console for MushroomObserver VM
  config.web_console.allowed_ips = "10.0.2.2"

  config.bot_enabled = true

  config.active_job.queue_adapter = :solid_queue

  # Set up ActionCable to use a standalone server at port 28080
  # config.action_cable.mount_path = nil
  # config.action_cable.url = "ws://localhost:28080" # use :wss in production
end

file = File.expand_path("../consts-site.rb", __dir__)
require(file) if File.exist?(file)

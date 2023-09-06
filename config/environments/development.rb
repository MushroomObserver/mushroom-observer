# frozen_string_literal: true

MushroomObserver::Application.configure do
  # Settings specified here take precedence over those in config/application.rb

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

  # Don't care if the mailer can't send
  config.action_mailer.raise_delivery_errors = false

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

  # In the development environment your application's code is reloaded on
  # every request.  This slows down response time but is perfect for development
  # since you don't have to restart the webserver when you make code changes.
  config.cache_classes = false

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Allow YAML deserializer to deserialize symbols
  # https://groups.google.com/g/rubyonrails-security/c/MmFO3LYQE8U?pli=1
  config.active_record.yaml_column_permitted_classes = [Symbol]

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Speed up Rails server boot time in development environment
  config.eager_load = false

  # Raise an error on page load if there are pending migrations
  config.active_record.migration_error = :page_load

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

  # Enable web console for MushroomObserver VM
  config.web_console.allowed_ips = "10.0.2.2"
end

file = File.expand_path("../consts-site.rb", __dir__)
require(file) if File.exist?(file)

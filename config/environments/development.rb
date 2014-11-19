MushroomObserver::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # ----------------------------
  #  MO configuration.
  # ----------------------------

  config.domain      = "localhost"
  config.http_domain = "http://localhost:3000"

  # List of alternate server domains.  We redirect from each of these to the real one.
  config.bad_domains = ["localhost.localdomain:3000"]

  # Code appended to ids to make "sync_id".  Must start with letter.
  config.server_code = "XX"

  # Turn off email.
  config.queue_email = false
  config.action_mailer.smtp_settings = {
    :address => "localhost",
    :port    => 25,
    :domain  => "localhost"
  }

  # Serve new images locally, pre-existing images from real image server.
  config.local_image_files = "#{config.root}/public/images"
  config.image_sources = {
    :local => {
      :test => "file://#{config.local_image_files}",
      :read => "/images",
    },
    :cdmr => {
      :test => :transferred_flag,
      :read => "http://images.digitalmycology.com",
    }
  }
  config.image_precedence = {
    :default => [:local, :cdmr]
  }
  config.image_fallback_source = :cdmr

  # ----------------------------
  #  Rails configuration.
  # ----------------------------

  # In the development environment your application's code is reloaded on
  # every request.  This slows down response time but is perfect for development
  # since you don't have to restart the webserver when you make code changes.
  config.cache_classes = false

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send
  config.action_mailer.raise_delivery_errors = false

  # Tell ActionMailer not to deliver emails to the real world.
  # The :file delivery method accumulates sent emails in the
  # ../mail directory.  (This is a feature I added. -JPH 20080213)
  config.action_mailer.delivery_method = :file

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin

  # Log the query plan for queries taking more than this (works
  # with SQLite, MySQL, and PostgreSQL)
  config.active_record.auto_explain_threshold_in_seconds = 0.5

  config.eager_load = false
end

file = File.expand_path("../../consts-site.rb", __FILE__)
require file if File.exist?(file)

# frozen_string_literal: true

MushroomObserver::Application.configure do
  # Settings specified here take precedence over those in config/application.rb

  # ----------------------------
  #  MO configuration.
  # ----------------------------

  config.domain      = "mushroomobserver.org"
  config.http_domain = "https://mushroomobserver.org"

  # List of alternate server domains.
  # We redirect from each of these to the real one.
  config.bad_domains = ["www.#{config.domain}"]

  # Date after which votes become public.
  config.vote_cutoff = "20100405"

  # Code appended to ids to make "sync_id".  Must start with letter.
  config.server_code = "us1"

  # Time zone of the server.
  config.time_zone = "America/New_York"
  ENV["TZ"] = "Eastern Time (US & Canada)"

  # Enable queued email.
  config.queue_email = true
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true

  # SMTP settings for gmail smtp-relay
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings =
    Rails.application.credentials.gmail_smtp_settings_webmaster

  config.image_precedence = {
    default: [:mycolab, :local]
    # For use when testing live server in parallel with production server.
    # :default   => [:mycolab, :local, :mo]
  }
  config.image_fallback_source = :mycolab

  config.robots_dot_text_file = "#{config.root}/public/robots.txt"

  # ----------------------------
  #  Rails configuration.
  #  The production environment is meant for finished, "live" apps.
  # ----------------------------

  # Code is not reloaded between requests
  config.cache_classes = true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both thread web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Enable Rack::Cache to put a simple HTTP cache in front of your application
  # Add `rack-cache` to your Gemfile before enabling this.
  # For large-scale production use, consider using a caching reverse proxy like
  # nginx, varnish or squid.
  # config.action_dispatch.rack_cache = true

  # Disable Rails's static asset server
  # In production, Apache or nginx will already do this
  config.public_file_server.enabled = false

  # Compress JavaScripts and CSS
  config.assets.compress = true
  config.assets.js_compressor = :terser
  config.assets.css_compressor = :sass

  # Do not fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # Generate digests for assets URLs
  config.assets.digest = true

  # Version of your assets, change this if you want to expire all your assets.
  config.assets.version = "1.0"

  # Specifies the header that your server uses for sending files
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for apache
  config.action_dispatch.x_sendfile_header = "X-Accel-Redirect" # For nginx
  # If you have no front-end server that supports something like X-Sendfile,
  # just comment this out and Rails will serve the files

  # Force all access to the app over SSL, use Strict-Transport-Security,
  # and use secure cookies.
  config.force_ssl = true

  # Set to :debug to see everything in the log.
  config.log_level = :info

  # Prepend all log lines with the following tags.
  # config.log_tags = [ :subdomain, :uuid ]

  # Use a different logger for distributed setups.
  # config.logger = ActiveSupport::TaggedLogging.new(SyslogLogger.new)

  # Use a different cache store in production
  # config.cache_store = :mem_cache_store

  # Enable serving of images, stylesheets, and javascripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"

  # Precompile additional assets.
  # application.js, application.css, and all non-JS/CSS in app/assets
  # folder are already added.

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = [I18n.default_locale]

  # Allow YAML deserializer to deserialize symbols
  # https://groups.google.com/g/rubyonrails-security/c/MmFO3LYQE8U?pli=1
  config.active_record.yaml_column_permitted_classes = [Symbol]

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  # Disable automatic flushing of the log to improve performance.
  # config.autoflush_log = false

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = Logger::Formatter.new if defined?(Logger)

  # Combine files using the "require" directives at the top of included files
  # See http://guides.rubyonrails.org/asset_pipeline.html#turning-debugging-off
  config.assets.debug = false

  config.bot_enabled = true
end

file = File.expand_path("../consts-site.rb", __dir__)
require(file) if File.exist?(file)

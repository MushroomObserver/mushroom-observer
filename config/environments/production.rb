MushroomObserver::Application.configure do
# Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.


  # ----------------------------
  #  MO configuration.
  # ----------------------------

  config.domain      = "mushroomobserver.org"
  config.http_domain = "http://mushroomobserver.org"

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

  # Testing
  config.action_mailer.delivery_method = :sendmail
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true

  # Serve new images locally until transferred to image server
  config.local_image_files = "#{config.root}/public/images"
  config.image_sources = {
    local: {
      test: "file://#{config.local_image_files}",
      read: "/local_images"
    },
    cdmr: {
      test: :transferred_flag,
      read: "/images",
      # Safer to keep this disabled until truly going live.
      # :write => "ssh://cdmr@digitalmycology.com:images.digitalmycology.com"
    }
    # For use when testing live server in parallel with production server.
    # :mo = {
    #   :test  => "http://mushroomobserver.org/local_images",
    #   :read  => "http://mushroomobserver.org/local_images",
    #   :write => "ssh://jason@mushroomobserver.org:/var/web/mo/public/images",
    #   :sizes => [ :thumbnail, :small ]
    # }
  }
  config.image_precedence = {
    default: [:cdmr, :local]
    # For use when testing live server in parallel with production server.
    # :default   => [:cdmr, :local, :mo]
  }
  config.image_fallback_source = :cdmr
  config.keep_these_image_sizes_local = []

  config.robots_dot_text_file = "#{config.root}/public/robots.txt"

  # ----------------------------
  #  Rails configuration.
  #  The production environment is meant for finished, "live" apps.
  # ----------------------------

  # Code is not reloaded between requests.
  config.cache_classes = true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?

  # Compress JavaScripts and CSS.
  config.assets.compress = true
  config.assets.js_compressor = :uglifier
  # config.assets.css_compressor = :sass

  # Do not fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # `config.assets.precompile` and `config.assets.version` have moved to config/initializers/assets.rb

  # Combine files using the "require" directives at the top of included files
  # See http://guides.rubyonrails.org/asset_pipeline.html#turning-debugging-off
  config.assets.debug = false

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.action_controller.asset_host = 'http://assets.example.com'

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = 'X-Sendfile' # for Apache
  config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for NGINX

  # Mount Action Cable outside main process or domain
  # config.action_cable.mount_path = nil
  # config.action_cable.url = 'wss://example.com/cable'
  # config.action_cable.allowed_request_origins = [ 'http://example.com', /http:\/\/example.*/ ]

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # Set to :debug to see everything in the log.
  config.log_level = :info

  # Prepend all log lines with the following tags.
  config.log_tags = [ :request_id ]

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store

  # Use a real queuing backend for Active Job (and separate queues per environment)
  # config.active_job.queue_adapter     = :resque
  # config.active_job.queue_name_prefix = "mushroom_observer_#{Rails.env}"
  config.action_mailer.perform_caching = false

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners.
  config.active_support.deprecation = :notify

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  # Use a different logger for distributed setups.
  # require 'syslog/logger'
  # config.logger = ActiveSupport::TaggedLogging.new(Syslog::Logger.new 'app-name')

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger           = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger = ActiveSupport::TaggedLogging.new(logger)
  end

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new if defined?(::Logger)

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false
end

file = File.expand_path("../../consts-site.rb", __FILE__)
require file if File.exist?(file)

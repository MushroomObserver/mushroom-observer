MushroomObserver::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # ----------------------------
  #  MO configuration.
  # ----------------------------

  config.domain      = "mushroomobserver.org"
  config.http_domain = "http://mushroomobserver.org"

  # List of alternate server domains.  We redirect from each of these to the real one.
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

  # Nathan wants a copy of everything.
  config.extra_bcc_email_addresses = "mo@collectivesource.com"

  # # Use gmail to send email.
  # config.action_mailer.smtp_settings = {
  #   :address => "smtp.gmail.com",
  #   :port => 587,
  #   :authentication => :plain,
  #   :enable_starttls_auto => true,
  #   :user_name => "webmaster@mushroomobserver.org",
  #   :password => "xxx"
  # }

  # Testing
  config.action_mailer.delivery_method = :sendmail
  # Defaults to:
  # config.action_mailer.sendmail_settings = {
  #   :location => '/usr/sbin/sendmail',
  #   :arguments => '-i -t'
  # }
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true

  # Serve new images locally until transferred to image server
  config.local_image_files = "#{config.root}/public/images"
  config.image_sources = {
    :local => {
      :test => "file://#{config.local_image_files}",
      :read => "/local_images",
    },
    :cdmr => {
      :test => :transferred_flag,
      :read  => "/images",
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
    :default   => [:cdmr, :local]
    # For use when testing live server in parallel with production server.
    # :default   => [:cdmr, :local, :mo]
  }
  config.image_fallback_source = :cdmr
  config.keep_these_image_sizes_local = [ :thumbnail, :small ]

  config.robots_dot_text_file = "#{config.root}/public/robots.txt"

  # ----------------------------
  #  Rails configuration.
  # ----------------------------

  # The production environment is meant for finished, "live" apps.
  # Code is not reloaded between requests
  config.cache_classes = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Specifies the header that your server uses for sending files
  # config.action_dispatch.x_sendfile_header = "X-Sendfile"

  # For nginx:
  config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect'

  # If you have no front-end server that supports something like X-Sendfile,
  # just comment this out and Rails will serve the files

  # See everything in the log (default is :info)
  # config.log_level = :debug

  # Use a different logger for distributed setups
  # config.logger = SyslogLogger.new

  # Use a different cache store in production
  # config.cache_store = :mem_cache_store

  # Disable Rails's static asset server
  # In production, Apache or nginx will already do this
  config.serve_static_assets = false

  # Enable serving of images, stylesheets, and javascripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"

  # Tells rails to let nginx serve static files.
  config.action_dispatch.x_sendfile_header = "X-Accel-Redirect"

  # Disable delivery errors, bad email addresses will be ignored
  # config.action_mailer.raise_delivery_errors = false

  # Enable threaded mode
  # config.threadsafe!

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  # Compress JavaScripts and CSS
  config.assets.compress = true
  config.assets.js_compressor = :uglifier

  # Don't fallback to assets pipeline if a precompiled asset is missed
  config.assets.compile = false

  # Combine files using the "require" directives at the top of included files
  config.assets.debug = false

  # Generate digests for assets URLs
  config.assets.digest = true

  # Defaults to Rails.root.join("public/assets")
  # config.assets.manifest = YOUR_PATH

  # Precompile stuff aside from application.js, application.css, all images.
  config.assets.precompile += %w(
    api_key.js
    edit_location.js
    multi_image_upload.js
    name_lister.js
    pivotal.js
    semantic_venacular.js
    translations.js
    vote_popup.js
    Admin.css
    Agaricus.css
    Amanita.css
    BlackOnWhite.css
    Cantharellaceae.css
    Hygrocybe.css
    grids.css
    semantic_vernacular.css
  )

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # What does this do?
  config.eager_load = true
end

file = File.expand_path("../../consts-site.rb", __FILE__)
require file if File.exist?(file)

# frozen_string_literal: true

MushroomObserver::Application.configure do
  # Settings specified here  take precedence over those in config/application.rb

  # ----------------------------
  #  MO configuration.
  # ----------------------------

  config.domain      = "mushroomobserver.org"
  config.http_domain = "https://mushroomobserver.org"

  # List of alternate server domains.
  # We redirect from each of these to the real one.
  config.bad_domains = ["www.mushroomobserver.org"]

  # Disable queued email.
  config.queue_email = false
  config.image_precedence = {
    default: [:local, :remote1]
  }
  config.image_fallback_source = :remote1

  config.robots_dot_text_file = "#{config.root}/test/fixtures/robots.txt"

  config.water_users = []
  config.oil_users   = []

  # REDIRECT_URI (Callback URL)
  # iNat calls this after iNat user authorizes MO to access their data.
  # Must match the redirect_uri in the iNat application settings for iNat's
  # MushroomObserver Test app https://www.inaturalist.org/oauth/applications/851
  config.redirect_uri =
    "http://localhost:3000/inat_imports/authorization_response"

  # ----------------------------
  #  Rails configuration.
  # ----------------------------

  # The test environment is used exclusively to run your application's
  # test suite.  You never need to work with it otherwise.  Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs.  Don't rely on the data there!
  # Rails 6 makes cache_classes default to false, but i'm keeping it true.
  # Also adds config.action_view.cache_template_loading, seems desirable
  # [Nimmo 20220526]
  config.cache_classes = true
  config.action_view.cache_template_loading = true

  # Do not eager load code on boot. This avoids loading your whole application
  # just for the purpose of running a single test. If you are using a tool that
  # preloads Rails for running tests, you may have to set it to true.
  config.eager_load = false

  # Configure static asset server for tests with Cache-Control for performance.
  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    "Cache-Control" => "public, max-age=3600"
  }

  # Show full error reports and disable caching.
  config.consider_all_requests_local = true
  # config.action_controller.perform_caching = false

  # Use a different cache store in test.
  config.cache_store = :null_store

  # Render exception templates for rescuable exceptions and raise for other
  # exceptions.
  # config.action_dispatch.show_exceptions = :rescuable
  # Raise exceptions instead of rendering exception templates.
  config.action_dispatch.show_exceptions = :none

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Use SQL, not Active Record's schema dumper, when creating the test database.
  # Necessary if your schema can't be completely dumped by the schema dumper,
  # like if you have constraints or database-specific column types
  # config.active_record.schema_format = :sql

  # Allow YAML deserializer to deserialize symbols
  # https://groups.google.com/g/rubyonrails-security/c/MmFO3LYQE8U?pli=1
  config.active_record.yaml_column_permitted_classes = [Symbol]
  # If test server is running puma for action cable,
  # ensure that test database is shared between threads
  # config.active_record.shared_connection = true

  # Debugging strict loading - either :log, or :error out the page
  # config.active_record.action_on_strict_loading_violation = :error

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Raises error for missing translations.
  # config.action_view.raise_on_missing_translations = true

  # Compile and combine assets, and add digests to names, but don't compress.
  config.assets.compile = true
  config.assets.digest = true
  config.assets.compress = false
  config.assets.debug = false

  # To control the debugger turing testing.
  config.activate_debugger = false

  # Enable stdout logger.
  config.logger = Logger.new($stdout)

  # Set log level.
  config.log_level = :ERROR

  # Suppress template digesting errors for Phlex components
  # (Phlex components don't have ERB templates to digest)
  config.action_view.logger = Logger.new($stdout).tap do |logger|
    logger.level = Logger::ERROR

    # Filter out the Phlex component template errors
    original_formatter = Logger::Formatter.new
    logger.formatter = proc do |severity, datetime, progname, msg|
      next if msg.to_s.include?("Couldn't find template for digesting: Components/")

      original_formatter.call(severity, datetime, progname, msg)
    end
  end

  # Raise error when a before_action's only/except options reference missing
  # actions
  config.action_controller.raise_on_missing_callback_actions = true

  # config.action_dispatch.show_exceptions = false

  config.active_support.test_order = :random

  config.bot_enabled = true

  config.active_job.queue_adapter = :test

  # ----------------------------
  #  Bullet configuration.
  # ----------------------------

  if defined?(Bullet)
    config.after_initialize do
      Bullet.enable = true
      Bullet.raise = true # Show message by raising errors.
      Bullet.stacktrace_includes = []
      Bullet.stacktrace_excludes = []
      Bullet.unused_eager_loading_enable = false
      # Bullet.add_safelist(type: :n_plus_one_query, class_name: "Post",
      #                     association: :comments)
      Bullet.add_safelist(type: :counter_cache, class_name: "Name",
                          association: :observations)
    end
  end
end

file = File.expand_path("../consts-site.rb", __dir__)
require(file) if File.exist?(file)

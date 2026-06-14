# frozen_string_literal: true

# Set env var to run with window:
# HEADLESS=0 rails test:system, or for a specific test:
# HEADLESS=0 rails t test/system/your_test.rb:234 (line number, optional)
require("test_helper")
require("database_cleaner/active_record")
require("capybara/cuprite")
require("test_helpers/system/cuprite_setup")
require("test_helpers/system/cuprite_helpers")

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # System tests use the Maps JavaScript API
  # (`@googlemaps/js-api-loader`); the key's HTTP-Referer whitelist
  # in Google Cloud Console gates which ports can call it. Start at
  # 3001 (not 3000) so a running `bin/rails server` on 3000 doesn't
  # collide with a worker. Count is the number of whitelisted ports
  # — bump (and ask Joe to widen the Cloud Console whitelist) when
  # we want more parallel system-test workers.
  MAPS_API_PORT_FIRST = 3001
  MAPS_API_PORT_COUNT = 3
  parallelize(workers: MAPS_API_PORT_COUNT)

  driven_by :mo_cuprite, using: :chromium
  # Include MO's helpers
  include GeneralExtensions
  include FlashExtensions
  include CapybaraSessionExtensions
  include CapybaraMacros
  include CupriteHelpers

  def setup
    # Be sure your test sets up/waits on authenticated requests correctly!
    ApplicationController.allow_forgery_protection = true

    # experimental, does it fix pending logins?
    Capybara.reset_sessions!
    # below is needed for cuprite
    Capybara.server = :puma
    # Capybara.current_driver = :mo_cuprite
    Capybara.server_host = "localhost"
    # Bind to a Maps-API-whitelisted port starting at
    # `MAPS_API_PORT_FIRST` (3001). One port per worker so they
    # don't fight — worker 0 → 3001, worker 1 → 3002, etc. Skipping
    # 3000 leaves a running `bin/rails server` on 3000 alone so
    # devs don't need to stop it before `bin/rails test test/system`.
    # Serial runs leave `TEST_ENV_NUMBER` unset → port 3001.
    Capybara.server_port = MAPS_API_PORT_FIRST + ENV["TEST_ENV_NUMBER"].to_i
    # Normalize whitespaces when using `has_text?` and similar matchers,
    # i.e., ignore newlines, trailing spaces, etc.
    # That makes tests less dependent on slight UI changes.
    Capybara.default_normalize_ws = true
    # Usually, especially when using Selenium, developers tend to increase the
    # max wait time. With Cuprite, there is no need for that - except on GitHub.
    # you can set the Capybara default value 2 here explicitly, but fails on CI.
    Capybara.default_max_wait_time = 3
    # disable CSS transitions and jQuery animations
    Capybara.disable_animation = true
    # Capybara.always_include_port = true
    # Capybara.raise_server_errors = true
    # default in test_helper = true. some SO threads suggest false
    self.use_transactional_tests = true

    # The Capybara.using_session allows you to manipulate a different browser
    # session, and thus, multiple independent sessions within a single test
    # scenario. That’s especially useful for testing real-time features, e.g.,
    # something with WebSocket. This patch tracks the name of the last session
    # used. We’re going to use this information to support taking failure
    # screenshots in multi-session tests.
    Capybara.singleton_class.prepend(Module.new do
      attr_accessor :last_used_session

      def using_session(name, &block)
        self.last_used_session = name
        super
      ensure
        self.last_used_session = nil
      end
    end)

    # https://github.com/DatabaseCleaner/database_cleaner
    # https://github.com/DatabaseCleaner/database_cleaner#minitest-example
    # https://stackoverflow.com/questions/15675125/database-cleaner-not-working-in-minitest-rails
    DatabaseCleaner.strategy = :transaction # :transaction :truncation
    DatabaseCleaner.start

    # Treat Rails html requests as coming from non-robots.
    # If it's a bot, controllers often do not serve the expected content.
    # The requester looks like a bot to the `browser` gem because the User Agent
    # in the request is blank. I don't see an easy way to change that. -JDC
    MO.bot_enabled = false
  end

  def teardown
    Capybara.reset_sessions!
    Capybara.use_default_driver

    DatabaseCleaner.clean

    ApplicationController.allow_forgery_protection = false
    MO.bot_enabled = true
  end
end

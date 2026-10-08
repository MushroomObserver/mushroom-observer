# frozen_string_literal: true

# Set env var to run with window:
# HEADLESS=0 rails test:system, or for a specific test:
# HEADLESS=0 rails t test/system/your_test.rb:234 (line number, optional)
require("test_helper")
require("database_cleaner/active_record")
require("capybara/cuprite")
require("test_helpers/system/cuprite_setup")
require("test_helpers/system/cuprite_helpers")

# `en.yml` is gitignored, so a branch switch leaves it stale -- same
# check `script/deploy.sh` runs before a deploy. `reload!` forces a
# re-read: test_helper above may have already cached the stale file
# into I18n before the shell script below gets a chance to fix it.
unless system("script/lang_update_if_needed.sh")
  raise("script/lang_update_if_needed.sh failed")
end

I18n.reload!

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Maps JS API key whitelists ports in Google Cloud Console --
  # start at 3001 (not 3000) so a running `bin/rails server` on
  # 3000 is left alone. Bump (and widen the whitelist) for more
  # parallel workers.
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
    # Capybara registers :puma logging a startup banner unless
    # Silent: true; the registered proc signature cannot take that
    # flag directly, so wrap registration and force it, keeping
    # NoTestConsoleNoise from flagging the first test per worker.
    unless Capybara.servers.names.include?(:puma_silent)
      Capybara.register_server(:puma_silent) do |app, port, host|
        Capybara.servers[:puma].call(app, port, host, Silent: true)
      end
    end
    Capybara.server = :puma_silent
    # Capybara.current_driver = :mo_cuprite
    Capybara.server_host = "localhost"
    # One Maps-whitelisted port per worker (MAPS_API_PORT_FIRST..+N),
    # skipping 3000 so a running `bin/rails server` is left alone.
    # Serial runs leave TEST_ENV_NUMBER unset -> port 3001.
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
    # BS4 custom-control checkboxes/radios hide the input (opacity: 0)
    # and paint the visible control via the sibling label -- check/
    # uncheck/choose fall back to clicking the label when the input
    # itself isn't interactable.
    Capybara.automatic_label_click = true
    # Capybara.always_include_port = true
    # Capybara.raise_server_errors = true
    # default in test_helper = true. some SO threads suggest false
    self.use_transactional_tests = true

    # using_session tracks the last session name for failure
    # screenshots across multi-session (e.g. WebSocket) tests.
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

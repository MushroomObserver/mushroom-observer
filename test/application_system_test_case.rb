# frozen_string_literal: true

require("test_helper")
require("database_cleaner/active_record")

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_firefox, screen_size: [1400, 1400]
  # Include MO's helpers
  include GeneralExtensions
  include FlashExtensions
  include CapybaraSessionExtensions
  include CapybaraMacros

  def setup
    ApplicationController.allow_forgery_protection = true

    Capybara.default_max_wait_time = 2
    # default in test_helper = true. some SO threads suggest false
    self.use_transactional_tests = false

    # needed for selenium
    Capybara.server = :webrick
    Capybara.current_driver = :selenium

    # https://github.com/DatabaseCleaner/database_cleaner
    # https://github.com/DatabaseCleaner/database_cleaner#minitest-example
    # https://stackoverflow.com/questions/15675125/database-cleaner-not-working-in-minitest-rails
    DatabaseCleaner.strategy = :truncation # :transaction :truncation
    DatabaseCleaner.start

    # Treat Rails html requests as coming from non-robots.
    # If it's a bot, controllers often do not serve the expected content.
    # The requester looks like a bot to the `browser` gem because the User Agent
    # in the request is blank. I don't see an easy way to change that. -JDC
    Browser::Bot.any_instance.stubs(:bot?).returns(false)
  end

  def teardown
    Capybara.reset_sessions!
    Capybara.use_default_driver

    DatabaseCleaner.clean

    ApplicationController.allow_forgery_protection = false
  end
end

# frozen_string_literal: true

# Allow simuluation of user-browser interaction with capybara
require("capybara/rails")
require("capybara/minitest")

#  = Capybara Integration Test Case
#
#  The test case class that all Capybara integration tests currently derive
#  from. Includes:
#
#    class YourTest < IntegrationTestCase
#
#      # Most basic test doesn't even need to know about session: all session
#      # methods are automatically delegated to a default session created at
#      # setup.
#      def test_simplest
#        visit('/controller/action?args=...')
#        click_button('Post Comment')
#        fill_in('message', 'This is a test.')
#        click_button('Post')
#      end
#
#      # More complicated session management, with CapybaraIntegrationExtensions
#      def test_multiple_session
#
#        # Create two sessions: think "browser" - each session represents the
#        # actions of a single user in one or more tabs of a single browser.
#        rolf_session = Capybara::Session.new(:rack_test, Rails.application)
#        using_session(rolf_session) { login_user('rolf') }
#        mary_session = Capybara::Session.new(:rack_test, Rails.application)
#        using_session(mary_session) { login_user('mary') }
#
#        # Have Rolf do some stuff.
#        using_session(rolf) { visit('/edit_rolfs_stuff') }
#
#        # Have Mary do stuff.
#        using_session(mary) { visit('/edit_rolfs_stuff') }
#        mary.assert_redirect
#
#        # You can also create anonymous sessions.
#        session = Capybara::Session.new(:rack_test, Rails.application)
#        session.visit('/show_index')
#        session.assert_selector('span', :text => 'Rolfs Thing', :count => 0)
#      end
#    end
#
################################################################################

class CapybaraIntegrationTestCase < ActionDispatch::IntegrationTest
  # Make the Capybara DSL available in these integration tests
  include Capybara::DSL
  # Make `assert_*` methods behave like Minitest assertions
  include Capybara::Minitest::Assertions

  include GeneralExtensions
  include FlashExtensions
  include CapybaraIntegrationExtensions

  # Important to allow integration tests test the CSRF stuff to avoid unpleasant
  # surprises in production mode.
  def setup
    ApplicationController.allow_forgery_protection = true

    # NOTE: rails-dom-testing only?
    # This should be automatically removed at the beginning of each test,
    # but for some reason it is not nil before the very first test run.
    # If it is not removed, then all sessions opened in your test will have
    # the identical session instance, breaking some tests. This is probably
    # a bug in rails, but as of 20190101 it is required.
    # @integration_session = nil

    # Treat Rails html requests as coming from non-robots.
    # If it's a bot, controllers often do not serve the expected content.
    # The requester looks like a bot to the `browser` gem because the User Agent
    # in the request is blank. I don't see an easy way to change that. -JDC
    Browser::Bot.any_instance.stubs(:bot?).returns(false)
  end

  def teardown
    Capybara.reset_sessions!
    Capybara.use_default_driver

    ApplicationController.allow_forgery_protection = false
  end
end

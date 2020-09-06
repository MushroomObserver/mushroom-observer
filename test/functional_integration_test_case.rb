# frozen_string_literal: true

#
#  = Functional Test Case
#
#  The test case class that all functional tests currently derive from.
#  Includes:
#
#  1. Some general-purpose helpers and assertions from GeneralExtensions.
#  2. Some controller-related helpers and assertions from ControllerExtensions.
#  3. A few helpers that encapsulate testing the flash error mechanism.
#
################################################################################

class FunctionalIntegrationTestCase < ActionDispatch::IntegrationTest
  include GeneralExtensions
  include SessionExtensions
  include FlashExtensions
  include CheckForUnsafeHtml
  include ControllerIntegrationExtensions

  # temporarily silence deprecation warnings
  # ActiveSupport::Deprecation.silenced = true

  def setup
    # Note: Disabling the forgery_protection CSRF stuff.
    # This breaks cookies and sessions in integration tests - JH, AN 8/20
    # ApplicationController.allow_forgery_protection = true

    # This should be automatically removed at the beginning of each test,
    # but for some reason it is not nil before the very first test run.
    # If it is not removed, then all sessions opened in your test will have
    # the identical session instance, breaking some tests. This is probably
    # a bug in rails, but as of 20190101 it is required.
    @integration_session = nil

    # Treat Rails html requests as coming from non-robots.
    # If it's a bot, controllers often do not serve the expected content.
    # The requester looks like a bot to the `browser` gem because the User Agent
    # in the request is blank. I don't see an easy way to change that. -JDC
    Browser::Generic.any_instance.stubs(:bot?).returns(false)
  end

  def teardown
    # ApplicationController.allow_forgery_protection = false
  end
end

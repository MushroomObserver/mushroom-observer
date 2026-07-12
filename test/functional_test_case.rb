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
#
# Disable cop because we currently use non-standard inheritance
class FunctionalTestCase < ActionController::TestCase # rubocop:disable Rails/ActionControllerTestCase
  include GeneralExtensions
  include FlashExtensions
  include ControllerExtensions
  include CheckForUnsafeHtml
  # Rails auto-includes this into ActionDispatch::IntegrationTest but not
  # ActionController::TestCase -- needed for assert_enqueued_email_with/
  # assert_no_enqueued_emails (deliver_later-based mailer assertions).
  include ActionMailer::TestHelper

  def get(action, **args)
    super
    check_for_unsafe_html!
  end

  def post(action, **args)
    super
    check_for_unsafe_html!
  end

  def put(action, **args)
    super
    check_for_unsafe_html!
  end

  def patch(action, **args)
    super
    check_for_unsafe_html!
  end

  def delete(action, **args)
    super
    check_for_unsafe_html!
  end
end

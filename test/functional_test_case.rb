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

class FunctionalTestCase < ActionController::TestCase
  include GeneralExtensions
  include FlashExtensions
  include ControllerExtensions
  include CheckForUnsafeHtml

  def get(action, **args, &block)
    super(action, **args, &block)
    check_for_unsafe_html!
  end

  def post(action, **args, &block)
    super(action, **args, &block)
    check_for_unsafe_html!
  end

  def put(action, **args, &block)
    super(action, **args, &block)
    check_for_unsafe_html!
  end

  def delete(action, **args, &block)
    super(action, **args, &block)
    check_for_unsafe_html!
  end
end

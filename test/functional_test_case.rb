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

  # temporarily silence deprecation warnings
  # ActiveSupport::Deprecation.silenced = true

  def get(*args, &block)
    super(*args, &block)
    check_for_unsafe_html!
  end

  def post(*args, &block)
    super(*args, &block)
    check_for_unsafe_html!
  end

  def put(*args, &block)
    super(*args, &block)
    check_for_unsafe_html!
  end

  def delete(*args, &block)
    super(*args, &block)
    check_for_unsafe_html!
  end
end

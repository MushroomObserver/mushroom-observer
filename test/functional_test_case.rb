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
end

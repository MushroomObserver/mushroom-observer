#
#  = Integration Test Session
#
#  This class is used to track a single browser for the integration tests.
#  Even though it is not the actual test case used by the unit test, it still
#  has full access to all the usual assertions and test helpers: 
#
#  1. Some general-purpose helpers and assertions from GeneralExtensions.
#  2. Several handy helpers making it easy to "navigate" around the mock site.
#  3. A few helpers that encapsulate testing the flash error mechanism.
#
#  == Relationship with IntegrationTestCase
#
#  The relationship between this class and IntegrationTestCase is nontrivial.
#  Please see the documentation for that class for more help.
#
#  Essentially, it is a has-many relationship, where the test case can have one
#  or more open sessions at a time, but always with one in particular being
#  considered the "current" session.  The current session is generally the last
#  one that was opened, however the unit test can change this at will.
#
#  The result is that the test case opens one or more of these sessions, then
#  performs actions and assertions on them and their results.  For convenience,
#  test cases can send these actions and assertions to the test case, which in
#  turn, will delegate to the currently-selected session.
#
#  *NOTE*: Though it hasn't been necessary yet, sessions have access back to
#  the parent test case via +test_case+.
#
################################################################################

class IntegrationSession < ActionController::Integration::Session
  include GeneralExtensions
  include FlashExtensions
  include SessionExtensions

  # Give session access to the owning IntegrationTestCase.
  attr_accessor :test_case

  # Rails makes this read-only for no apparent reason.
  attr_accessor :cookies
end

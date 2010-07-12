#
#  = Integration High-Level Test Helpers
#
#  Methods in this class are available to all the integration tests.
#
#  login::    Log a user in using nothing but HTTP requests.
#
################################################################################

module IntegrationExtensions

  # Login a given user via website using nothing but HTTP requests.  Creates
  # and returns a new IntegrationSession.  This session will also be made the
  # "current" session. 
  def login(user, password='testpassword', remember_me=true)
    open_session do |sess|
      sess.login(user, password, remember_me)
    end
  end

  # Same as +login+ except that it fails an assertion if it fails.
  def login!(user, password='testpassword', remember_me=true)
    open_session do |sess|
      sess.login!(user, password, remember_me)
    end
  end
end

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
  def login(login, password='testpassword', remember_me=true)
    open_session do
      get('account/login')
      do_form('form[action$=login]') do |form|
        form.edit_field('login', login)
        form.edit_field('password', password)
        form.edit_field('remember_me', remember_me ? '1' : '0')
        form.submit('Login')
      end
    end
  end
end

# frozen_string_literal: true

#
#  = Integration High-Level Test Helpers
#
#  Methods in this class are available to all the integration tests.
#
#  login::   Create a session with a given user logged in.
#  login!::  Same thing,but raise an error if it is unsuccessful.
#
################################################################################

module IntegrationExtensions
  # Login the given user in the current session.
  def login(login, password = "testpassword", remember_me = true)
    login = login.login if login.is_a?(User)
    get("/account/login")
    open_form do |form|
      form.change("login", login)
      form.change("password", password)
      form.change("remember_me", remember_me)
      form.submit("Login")
    end
  end

  # Login the given user, testing to make sure it was successful.
  def login!(user, *args)
    login(user, *args)
    assert_flash(/success/i)
    user = User.find_by_login(user) if user.is_a?(String)
    assert_users_equal(user, assigns(:user), "Wrong user ended up logged in!")
  end
end

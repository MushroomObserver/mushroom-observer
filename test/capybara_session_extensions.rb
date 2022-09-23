# frozen_string_literal: true

#
#  = Integration High-Level Test Helpers
#
#  Methods in this class are available to Capybara integration tests.
#
#  login::   Create a session with a given user logged in.
#  login!::  Same thing,but raise an error if it is unsuccessful.
#
#
module CapybaraSessionExtensions
  # Login the given user in the current session.
  def login(login = users(:zero_user).login, password = "testpassword",
            remember_me = true)
    login = login.login if login.is_a?(User)
    visit("/account/login")

    fill_in("user_login", with: login)
    fill_in("user_password", with: password)
    check("user_remember_me") if remember_me == true

    click_button("Login")
  end

  # Login the given user, testing to make sure it was successful.
  def login!(user, *args)
    login(user, *args)
    assert_flash(/success/i)
    user = User.find_by(login: user) if user.is_a?(String)
    assert_users_equal(user, assigns(:user), "Wrong user ended up logged in!")
  end

  # The current_path plus the query, similar to @request.fullpath
  def current_fullpath
    URI.parse(current_url).request_uri
  end

  def current_path_id
    current_path.split("/").last
  end

  # Get string representing (our) query from the given URL.  Defaults to the
  # current page's URL.  (In practice, for now, this is just the Query id.)
  def parse_query_params(url = current_fullpath)
    _path, query = url.split("?")
    params = CGI.parse(query)
    params["q"]
  end

  def assert_flash_text(text = "")
    assert_selector("#flash-notices")
    assert_selector("#flash-notices", text: text)
  end

  def assert_no_flash
    refute_selector("#flash-notices")
  end

  def assert_flash_success
    assert_selector("#flash-notices.alert-success")
  end
end

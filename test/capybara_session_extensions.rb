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
    visit("/account/login/new")

    within("#account_login_form") do
      fill_in("user_login", with: login)
      fill_in("user_password", with: password)
      check("user_remember_me") if remember_me == true

      click_commit
    end
  end

  # Login the given user, testing to make sure it was successful.
  def login!(user, *args)
    login(user, *args)
    assert_flash_success
    user = User.find_by(login: user) if user.is_a?(String)
    assert_equal(user.id, User.current_id, "Wrong user ended up logged in!")
  end

  def put_user_in_admin_mode(user = :zero_user)
    user.admin = true
    user.save!
    login(user.login)
    assert_equal(user.id, User.current_id)

    click_on(id: "user_nav_admin_mode_link")
    assert_match(/DANGER: You are in administrator mode/, page.html)
  end

  # The current_path plus the query, similar to @request.fullpath
  # URI.parse(current_url).request_uri gives same result but slower
  def current_fullpath
    current_url[current_host.size..]
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
    assert_selector("#flash_notices")
    assert_selector("#flash_notices", text: text)
  end

  def assert_no_flash
    refute_selector("#flash_notices")
  end

  def assert_flash_success
    assert_selector("#flash_notices.alert-success")
  end

  # Capybara has built-in go_back and go_forward methods for js-enabled drivers
  # like :webkit or :selenium -- e.g., Capybara::Webkit::Driver#go_back
  # This method provides a similar function for the built-in driver :rack_test
  def go_back_after(&block)
    @page_stack ? @page_stack.push(current_path) : @page_stack = [current_path]
    yield(block)
    visit(@page_stack.pop)
  end

  # Many forms have more than one submit button
  def click_commit
    first(:button, type: "submit", name: "commit").click
  end
end

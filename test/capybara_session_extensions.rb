# frozen_string_literal: true

#
#  = Integration High-Level Test Helpers
#
#  Methods in this class are available to Capybara integration tests.
#
#  login::   Create a session with a given user logged in.
#  login!::  Same thing,but raise an error if it is unsuccessful.
#
#  NOTE: these cannot actually extend a named session yet.
#
module CapybaraSessionExtensions
  # Open a trackable session. Not necessary unless testing parallel sessions.
  def open_session(driver = :rack_test)
    Capybara::Session.new(driver, Rails.application)
  end

  # Login the given user in the current session.
  def login(login = users(:zero_user).login, password = "testpassword",
            remember_me = true, session: nil)
    login = login.login if login.is_a?(User) # get the right user field
    if session.is_a?(Capybara::Session)
      session.visit("/account/login/new")

      session.within("#account_login_form") do
        session.fill_in("user_login", with: login)
        session.fill_in("user_password", with: password)
        session.check("user_remember_me") if remember_me == true

        session.first(:button, type: "submit").click
      end
    else
      visit("/account/login/new")

      within("#account_login_form") do
        fill_in("user_login", with: login)
        fill_in("user_password", with: password)
        check("user_remember_me") if remember_me == true

        click_commit
      end
    end
  end

  # Login the given user, testing to make sure it was successful.
  def login!(user, *args, **kwargs)
    login(user, *args, **kwargs)
    session = kwargs ? kwargs[:session] : nil
    assert_flash_success(session: session)
    user = User.find_by(login: user) if user.is_a?(String)
    assert_equal(user.id, User.current_id, "Wrong user ended up logged in!")
  end

  def logout
    visit("/account/logout")
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

  # Mail parsing methods. Pass `pos` to get nth-from-last mail delivered
  def delivered_mail(pos = 1)
    ActionMailer::Base.deliveries.last(pos).first
  end

  # Just the HTML
  def delivered_mail_html(pos = 1)
    delivered_mail(pos).body.raw_source
  end

  def delivered_mail_data(pos = 1)
    Nokogiri::HTML(delivered_mail_html(pos))
  end

  def first_link_in_mail(pos = 1)
    href_value = delivered_mail_data(pos).at_css("a")[:href]
    URI.parse(href_value).request_uri
  end

  def assert_flash_text(text = "", session: nil)
    if session.is_a?(Capybara::Session)
      session.assert_selector("#flash_notices")
      session.assert_selector("#flash_notices", text: text)
    else
      assert_selector("#flash_notices")
      assert_selector("#flash_notices", text: text)
    end
  end

  def assert_no_flash_text(text = "", session: nil)
    if session.is_a?(Capybara::Session)
      session.assert_no_selector("#flash_notices", text: text)
    else
      assert_no_selector("#flash_notices", text: text)
    end
  end

  def assert_no_flash(session: nil)
    if session.is_a?(Capybara::Session)
      session.assert_no_selector("#flash_notices")
    else
      assert_no_selector("#flash_notices")
    end
  end

  def assert_flash_success(text = "", session: nil)
    if session.is_a?(Capybara::Session)
      session.assert_selector("#flash_notices.alert-success")
      assert_flash_text(text, session: session) if text
    else
      assert_selector("#flash_notices.alert-success")
      assert_flash_text(text) if text
    end
  end

  def assert_flash_error(text = "", session: nil)
    if session.is_a?(Capybara::Session)
      session.assert_any_of_selectors("#flash_notices.alert-error",
                                      "#flash_notices.alert-danger")
      assert_flash_text(text, session: session) if text
    else
      assert_any_of_selectors("#flash_notices.alert-error",
                              "#flash_notices.alert-danger")
      assert_flash_text(text) if text
    end
  end

  def assert_no_flash_errors(session: nil)
    if session.is_a?(Capybara::Session)
      session.assert_none_of_selectors("#flash_notices.alert-error",
                                       "#flash_notices.alert-danger")
    else
      assert_none_of_selectors("#flash_notices.alert-error",
                               "#flash_notices.alert-danger")
    end
  end

  def assert_flash_warning(text = "", session: nil)
    if session.is_a?(Capybara::Session)
      session.assert_selector("#flash_notices.alert-warning")
      assert_flash_text(text, session: session) if text
    else
      assert_selector("#flash_notices.alert-warning")
      assert_flash_text(text) if text
    end
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
  def click_commit(session: nil)
    if session.is_a?(Capybara::Session)
      session.first(:button, type: "submit").click
    else
      first(:button, type: "submit").click
    end
  end

  # def string_value_is_number?(string)
  #   Float(string, exception: false)
  # end

  # fields have to be { field => { type:, value: } }
  def assert_form_has_correct_values(expected_fields, form_selector)
    within(form_selector) do
      expected_fields.each do |key, field|
        if field[:type] == :select
          assert_select(key, selected: field[:value])
        elsif field[:type].in?([:check, :radio]) && field[:value] == true
          assert_checked_field(key)
        elsif field[:type].in?([:check, :radio]) && field[:value] == false
          assert_unchecked_field(key)
        elsif field[:type] == :text && field[:value] == ""
          assert_field(key, text: field[:value])
        else
          assert_field(key, with: field[:value])
        end
      end
    end
  end

  # fields have to be { field => { type:, value: } }
  def submit_form_with_changes(changes, form_selector)
    within(form_selector) do
      changes.each do |key, change|
        if change.key?(:visible)
          set_hidden_field(key, change)
        elsif change[:type] == :select
          select(change[:value], from: key)
        elsif change[:type] == :file
          attach_file(key, change[:value])
        elsif change[:type] == :check && change[:value] == true
          check(key)
        elsif change[:type] == :check && change[:value] == false
          uncheck(key)
        elsif change[:type] == :radio
          choose(change[:value])
        elsif change[:type] == :text
          fill_in(key, with: change[:value])
        end
      end
      first(:button, type: "submit").click
    end
  end

  # change[:field] should be an ID, unless u wanna get fancy
  def set_hidden_field(id, field)
    first("##{id}", visible: false).set(field[:value])
  end

  # Capybara can only select by text, but that's subject to translation
  def select_by_value(id, option)
    find_field(id.to_s).find("option[value='#{option}']").select_option
  end
end

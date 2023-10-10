# frozen_string_literal: true

#
#  = Capybara Integration Test Helpers
#
#  open_session:: Create a separate named session (for testing concurrent
#                 sessions). Not necessary for single session tests.
#                 Pass a driver arg to change drivers (default is :rack_test)
#
#  = Session-specific methods:
#    To use a method within a named session, pass the `session:` kwarg
#
#  login::   Log user in to current session.
#  login!::  Same thing, but raise an error if it is unsuccessful.
#  logout
#  put_user_in_admin_mode
#  current_fullpath
#  current_path_id
#  parse_query_params
#  delivered_mail
#  delivered_mail_html
#  delivered_mail_data
#  first_link_in_mail
#  assert_no_flash
#  assert_flash_text
#  assert_no_flash_text
#  assert_flash_success
#  assert_flash_error
#  assert_no_flash_errors
#  assert_flash_warning
#  go_back_after
#  click_commit
#  assert_form_has_correct_values
#  submit_form_with_changes
#  set_hidden_field
#  select_by_value
#
module CapybaraSessionExtensions
  # Open a separate session. Not necessary unless testing parallel sessions.
  def open_session(driver = :rack_test)
    Capybara::Session.new(driver, Rails.application)
  end

  # Login the given user in the current session.
  def login(login = users(:zero_user).login, password = "testpassword",
            remember_me = true, session: self)
    login = login.login if login.is_a?(User) # get the right user field
    session.visit("/account/login/new")
    session.assert_selector("body.login__new")

    session.within("#account_login_form") do
      session.fill_in("user_login", with: login)
      session.fill_in("user_password", with: password)
      session.assert_checked_field("user_remember_me")
      session.uncheck("user_remember_me") if remember_me == false

      session.first(:button, type: "submit").click
    end
  end

  # Login the given user, testing to make sure it was successful.
  def login!(user, *args, **kwargs)
    login(user, *args, **kwargs)
    session = kwargs[:session] || self
    assert_flash_success(session: session)
    user = User.find_by(login: user) if user.is_a?(String)
    assert_equal(user.id, User.current_id, "Wrong user ended up logged in!")
  end

  def logout(session: self)
    session.visit("/account/logout")
  end

  def put_user_in_admin_mode(user = :zero_user, session: self)
    user.admin = true
    user.save!
    login(user.login, session: session)
    assert_equal(user.id, User.current_id)

    session.click_on(id: "user_nav_admin_mode_link")
    assert_match(/DANGER: You are in administrator mode/, page.html)
  end

  # The current_path plus the query, similar to @request.fullpath
  # URI.parse(current_url).request_uri gives same result but slower
  def current_fullpath(session: self)
    session.current_url[current_host.size..]
  end

  def current_path_id(session: self)
    session.current_path.split("/").last
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

  def assert_no_flash(session: self)
    session.assert_no_selector("#flash_notices")
  end

  def assert_flash_text(text = "", session: self)
    session.assert_selector("#flash_notices")
    session.assert_selector("#flash_notices", text: text)
  end

  def assert_no_flash_text(text = "", session: self)
    session.assert_no_selector("#flash_notices", text: text)
  end

  def assert_flash_success(text = "", session: self)
    session.assert_selector("#flash_notices.alert-success")
    assert_flash_text(text, session: session) if text
  end

  def assert_flash_error(text = "", session: self)
    session.assert_any_of_selectors("#flash_notices.alert-error",
                                    "#flash_notices.alert-danger")
    assert_flash_text(text, session: session) if text
  end

  def assert_no_flash_errors(session: self)
    session.assert_none_of_selectors("#flash_notices.alert-error",
                                     "#flash_notices.alert-danger")
  end

  def assert_flash_warning(text = "", session: self)
    session.assert_selector("#flash_notices.alert-warning")
    assert_flash_text(text, session: session) if text
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
  def click_commit(session: self)
    session.first(:button, type: "submit").click
  end

  # # Cuprite: must scroll to the button or you can't click?
  # def scroll_and_click_commit(session: self)
  #   button = session.first(:button, type: "submit")
  #   session.scroll_to(button, align: :center)
  #   button.click
  # end

  # def scroll_and_click_button(locator, *options)
  #   session = self

  #   button = session.find_button(locator, *options)
  #   session.scroll_to(button, align: :center)
  #   button.click
  # end

  # def scroll_and_check(locator, **options)
  #   session = options[:session] || self
  #   label = session.find("label[for='#{locator}']")
  #   session.scroll_to(label, align: :center)
  #   label.click
  # end

  def click_file_field(locator, session: self)
    label = session.find(locator)
    session.scroll_to(label, align: :center)
    # sleep(1) # because scroll-behavior: smooth
    label.trigger(:click)
  end

  # def string_value_is_number?(string)
  #   Float(string, exception: false)
  # end

  # fields have to be { field => { type:, value: } }
  # Not sure the assertions need `form` or `within() do` needs `|form|`
  def assert_form_has_correct_values(expected_fields, form_selector,
                                     session: self)
    session.within(form_selector) do |form|
      expected_fields.each do |key, field|
        if field[:type] == :select
          assert(form.has_select?(key, selected: field[:value]))
        elsif field[:type].in?([:check, :radio]) && field[:value] == true
          assert(form.has_checked_field?(key))
        elsif field[:type].in?([:check, :radio]) && field[:value] == false
          assert(form.has_unchecked_field?(key))
        elsif field[:type] == :text && field[:value] == ""
          assert(form.has_field?(key, text: field[:value]))
        else
          assert(form.has_field?(key, with: field[:value]))
        end
      end
    end
  end

  # fields have to be { field => { type:, value: } }
  def submit_form_with_changes(changes, form_selector, session: self)
    session.within(form_selector) do |form|
      changes.each do |key, change|
        if change.key?(:visible)
          set_hidden_field(key, change, form)
        elsif change[:type] == :select
          form.select(change[:value], from: key)
        elsif change[:type] == :file
          form.attach_file(key, change[:value])
        elsif change[:type] == :check && change[:value] == true
          form.check(key)
        elsif change[:type] == :check && change[:value] == false
          form.uncheck(key)
        elsif change[:type] == :radio
          form.choose(change[:value])
        elsif change[:type] == :autocompleter
          form.fill_in(key, with: change[:value])
          form.assert_field(key, with: change[:value])
        elsif change[:type] == :text
          form.fill_in(key, with: change[:value])
        end
      end
      form.first(:button, type: "submit").click
    end
  end

  # change[:field] should be an ID, unless u wanna get fancy
  def set_hidden_field(id, field, form = self)
    form.first("##{id}", visible: false).set(field[:value])
  end

  # Capybara can only select by text, but that's subject to translation
  def select_by_value(id, option, form = self)
    form.find_field(id.to_s).find("option[value='#{option}']").select_option
  end
end

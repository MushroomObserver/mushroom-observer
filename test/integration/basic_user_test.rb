# Test typical sessions of user who never creates an account or contributes.

require File.dirname(__FILE__) + '/../boot'

class BasicUserTest < IntegrationTestCase
  def test_login
    # Start at index.
    get('/')
    save_path = path

    # Login.
    click_on(:label => 'Login', :in => :left_panel)
    assert_template('account/login')

    # Try to login without a password.
    do_form('form[action$=login]') do |form|
      form.assert_value('login', '')
      form.assert_value('password', '')
      form.assert_value('remember_me', '1')
      form.edit_field('login', 'rolf')
      form.submit('Login')
    end
    assert_template('account/login')
    assert_flash(/unsuccessful/i)

    # Try again with incorrect password.
    do_form('form[action$=login]') do |form|
      form.assert_value('login', 'rolf')
      form.assert_value('password', '')
      form.assert_value('remember_me', '1')
      form.edit_field('password', 'boguspassword')
      form.submit('Login')
    end
    assert_template('account/login')
    assert_flash(/unsuccessful/i)

    # Try yet again with correct password.
    do_form('form[action$=login]') do |form|
      form.assert_value('login', 'rolf')
      form.assert_value('password', '')
      form.assert_value('remember_me', '1')
      form.edit_field('password', 'testpassword')
      form.submit('Login')
    end
    assert_template('observer/list_rss_logs')
    assert_flash(/success/i)

    # This should only be accessible if logged in.
    click_on(:label => 'Preferences', :in => :left_panel)
    assert_template('account/prefs')

    # Log out and try again.
    click_on(:label => 'Logout', :in => :left_panel)
    assert_template('account/logout_user')
    assert_raises(Test::Unit::AssertionFailedError) do
      click_on(:label => 'Preferences', :in => :left_panel)
    end
    get_via_redirect('/account/prefs')
    assert_template('account/login')
  end

  def test_autologin
    login('rolf', 'testpassword', :true)
    rolf_cookies = cookies.dup
    rolf_cookies.delete('mo_session')
    assert_match(/^1/, rolf_cookies['mo_user'])

    login('mary', 'testpassword', true)
    mary_cookies = cookies.dup
    mary_cookies.delete('mo_session')
    assert_match(/^2/, mary_cookies['mo_user'])

    login('dick', 'testpassword', false)
    dick_cookies = cookies.dup
    dick_cookies.delete('mo_session')
    assert_equal('', dick_cookies['mo_user'])

    open_session do
      self.cookies = rolf_cookies
      get_via_redirect('/account/prefs')
      assert_template('account/prefs')
      assert_users_equal(@rolf, assigns(:user))
    end

    open_session do
      self.cookies = mary_cookies
      get_via_redirect('/account/prefs')
      assert_template('account/prefs')
      assert_users_equal(@mary, assigns(:user))
    end

    open_session do
      self.cookies = dick_cookies
      get_via_redirect('/account/prefs')
      assert_template('account/login')
    end
  end
end

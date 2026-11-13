# frozen_string_literal: true

require("test_helper")

class AutologinIntegrationTest < IntegrationTestCase
  # ----------------------------
  #  Test autologin cookies.
  # ----------------------------

  def test_autologin
    rolf_cookies = get_cookies(rolf, true)
    mary_cookies = get_cookies(mary, true)
    dick_cookies = get_cookies(dick, false)
    try_autologin(rolf_cookies, rolf)
    try_autologin(mary_cookies, mary)
    try_autologin(dick_cookies, false)
  end

  # Without the blank-auth_code guard, a cookie carrying only an id
  # splits to a nil secret, which compares equal to a null stored code.
  def test_autologin_refuses_blank_auth_code
    rolf.update_column(:auth_code, nil)
    sess = open_session
    sess.cookies["mo_user"] = rolf.id.to_s
    sess.get("/account/preferences/edit")

    sess.assert_select("form[action='/account/preferences']", count: 0)
    sess.assert_select("#account_login_form")
  end

  def get_cookies(user, autologin)
    sess = open_session
    sess.login(user, "testpassword", autologin)
    result = sess.cookies.dup
    if autologin
      assert_match(/^#{user.id}/, result["mo_user"])
    else
      assert_equal("", result["mo_user"].to_s)
    end
    result
  end

  def try_autologin(cookies, user)
    sess = open_session
    sess.cookies["mo_user"] = cookies["mo_user"]
    sess.get("/account/preferences/edit")
    if user
      # Autologin succeeded — preferences-edit form is rendered.
      # form_with model: @user, url: account_preferences_path posts to
      # /account/preferences (PATCH via _method hidden field).
      sess.assert_select("form[action='/account/preferences']")
      sess.assert_select("#account_login_form", count: 0)
      assert_users_equal(user, sess.assigns(:user))
    else
      # No autologin — login form is rendered instead.
      sess.assert_select("form[action='/account/preferences']", count: 0)
      sess.assert_select("#account_login_form")
    end
  end
end

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
      sess.assert_select("form[action*='account/preferences/edit']")
      sess.assert_select("form[action*='account/login/new']", count: 0)
      assert_users_equal(user, sess.assigns(:user))
    else
      # No autologin — login form is rendered instead.
      sess.assert_select("form[action*='account/preferences/edit']",
                         count: 0)
      sess.assert_select("form[action*='account/login/new']")
    end
  end
end

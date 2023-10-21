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
      sess.assert_match("account/preferences/edit", sess.response.body)
      sess.assert_no_match("account/login/new", sess.response.body)
      assert_users_equal(user, sess.assigns(:user))
    else
      sess.assert_no_match("account/preferences/edit", sess.response.body)
      sess.assert_match("account/login/new", sess.response.body)
    end
  end
end

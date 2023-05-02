# frozen_string_literal: true

require("test_helper")

# Test typical sessions of amateur user who just posts the occasional comment,
# observations, or votes.
class AmateurTest < IntegrationTestCase
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

  # ------------------------------------------------------------------------
  #  Quick test to try to catch a bug that the functional tests can't seem
  #  to catch.  (Functional tests can survive undefined local variables in
  #  partials, but not integration tests.)
  # ------------------------------------------------------------------------

  def test_edit_image
    login("mary")
    get("/images/1/edit")
  end

  # ------------------------------------------------------------------------
  #  Tests to make sure that the proper links are rendered  on the  home page
  #  when a user is logged in.
  #  test_user_dropdown_avaiable:: tests for existence of dropdown bar & links
  #
  # ------------------------------------------------------------------------

  def test_user_dropdown_avaiable
    login("dick")
    get("/")
    assert_select("li#user_drop_down")
    links = css_select("li#user_drop_down a")
    assert_equal(links.length, 7)
  end

end

# frozen_string_literal: true

require("test_helper")

# Test user AccountControllerTest
# signup, verification, prefs, profile, api
class AccountControllerTest < FunctionalTestCase
  def setup
    @request.host = "localhost"
    super
  end

  ##############################################################################

  def test_signup
    @request.session["return-to"] = "http://localhost/bogus/location"
    num_users = User.count
    post(:create, params: { new_user: {
           login: " newbob ",
           password: " newpassword ",
           password_confirmation: " newpassword ",
           email: " webmaster@mushroomobserver.org ",
           email_confirmation: "  webmaster@mushroomobserver.org  ",
           name: " needs a name! ",
           theme: "NULL"
         } })
    assert_equal("http://localhost/bogus/location", @response.redirect_url)
    assert_equal(num_users + 1, User.count)
    user = User.last
    assert_equal("newbob", user.login)
    assert_equal("needs a name!", user.name)
    assert_equal("webmaster@mushroomobserver.org", user.email)
    assert_nil(user.verified)
    assert_equal(false, user.admin)

    # Make sure user groups are updated correctly.
    assert(UserGroup.all_users.users.include?(user))
    assert(group = UserGroup.one_user(user))
    assert_user_arrays_equal([user], group.users)

    # Make sure user stats are created.
    assert_not_nil(user.user_stats)
  end

  def test_bad_signup
    @request.session["return-to"] = "http://localhost/bogus/location"

    params = {
      login: "newbob",
      password: "topsykritt",
      password_confirmation: "topsykritt",
      email: "blah@somewhere.org",
      email_confirmation: "blah@somewhere.org",
      mailing_address: "",
      theme: "NULL",
      notes: ""
    }

    # Missing password.
    post(:create, params: { new_user: params.except(:password) })
    assert_flash_error
    assert_response(:success)
    assert(assigns("new_user").errors[:password].any?)

    # Password doesn't match
    post(:create,
         params: { new_user: params.merge(password_confirmation: "wrong") })
    assert_flash_error
    assert_response(:success)
    assert(assigns("new_user").errors[:password].any?)

    # No email
    post(:create, params: { new_user: params.except(:email) })
    assert_flash_error
    assert_response(:success)
    assert(assigns("new_user").errors[:email].any?,
           assigns("new_user").dump_errors)

    # Invalid email
    post(:create, params: { new_user: params.merge(email: "wrong") })
    assert_flash_error
    assert_response(:success)
    assert(assigns("new_user").errors[:email].any?,
           assigns("new_user").dump_errors)

    # Email doesn't match.
    post(:create,
         params: { new_user: params.merge(email_confirmation: "wrong") })
    assert_flash_error
    assert_response(:success)
    assert(assigns("new_user").errors[:email].any?)

    # Make sure correct request would have succeeded!
    post(:create, params: { new_user: params })
    assert_flash_success
    assert_redirected_to("/bogus/location")
    assert_not_nil(user_id = User.find_by(login: "newbob"))
    assert_not_nil(UserStats.find_by(user_id: user_id))
  end

  def test_signup_theme_errors
    referrer = "http://localhost/bogus/location"

    params = {
      login: "spammer",
      password: "spammer",
      password_confirmation: "spammer",
      email: "spam@spam.spam",
      mailing_address: "",
      notes: ""
    }

    @request.session["return-to"] = referrer
    post(:create, params: { new_user: params.merge(theme: "") })
    assert_no_flash
    assert_nil(User.find_by(login: "spammer"))
    assert_nil(@request.session["user_id"])
    assert_redirected_to(referrer)

    @request.session["return-to"] = referrer
    post(:create, params: { new_user: params.merge(theme: "spammer") })
    assert_no_flash
    assert_nil(User.find_by(login: "spammer"))
    assert_nil(@request.session["user_id"])
    assert_redirected_to(referrer)
  end

  def test_anon_user_signup
    get(:new)

    assert_response(:success)
    assert_head_title(:signup_title.l)
  end

  def test_anon_user_welcome
    get(:welcome)

    assert_response(:success)
    assert_head_title(:welcome_no_user_title.l)
  end

  def test_block_known_evil_signups
    params = {
      login: "newbob",
      password: "topsykritt",
      password_confirmation: "topsykritt",
      email: "blah@somewhere.org",
      email_confirmation: "blah@somewhere.org",
      mailing_address: "",
      theme: "NULL",
      notes: ""
    }
    html_client_error = 400..499

    post(:create, params: { new_user: params.merge(login: "xUplilla") })
    assert(html_client_error.include?(response.status),
           "Signup response should be 4xx")

    post(:create, params: { new_user: params.merge(email: "x@namnerbca.com") })
    assert(html_client_error.include?(response.status),
           "Signup response should be 4xx")

    post(:create,
         params: {
           new_user: params.merge(email: "b.l.izk.o.ya.n201.7@gmail.com\r\n")
         })
    assert(html_client_error.include?(response.status),
           "Signup response should be 4xx")
  end
end

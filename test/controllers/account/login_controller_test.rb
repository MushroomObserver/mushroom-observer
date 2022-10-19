# frozen_string_literal: true

require("test_helper")

# tests of Login controller
module Account
  class LoginControllerTest < FunctionalTestCase
    def setup
      @request.host = "localhost"
      super
    end

    ############################################################################

    def test_auth_rolf
      @request.session["return-to"] = "http://localhost/bogus/location"
      post(:create,
           params: { user: { login: "rolf", password: "testpassword" } })
      assert_response("http://localhost/bogus/location")
      assert_flash_text(:runtime_login_success.t)
      assert(@request.session[:user_id],
             "Didn't store user in session after successful login!")
      assert_equal(rolf.id, @request.session[:user_id],
                   "Wrong user stored in session after successful login!")
    end

    def test_anon_user_login
      get(:new)

      assert_response(:success)
      assert_head_title(:login_please_login.l)
    end

    def test_invalid_login
      post(:create,
           params: { user: { login: "rolf", password: "not_correct" } })
      assert_nil(@request.session["user_id"])
      assert_template("account/login/new")

      user = User.create!(
        login: "api",
        email: "foo@bar.com"
      )
      post(:create, params: { user: { login: "api", password: "" } })
      assert_nil(@request.session["user_id"])
      assert_template("account/login/new")

      user.update(verified: Time.zone.now)
      post(:create, params: { user: { login: "api", password: "" } })
      assert_nil(@request.session["user_id"])
      assert_template("account/login/new")

      user.change_password("try_this_for_size")
      post(:create,
           params: { user: { login: "api", password: "try_this_for_size" } })
      assert(@request.session["user_id"])
    end

    # Test autologin feature.
    def test_autologin
      # Make sure test page that requires login fails without autologin cookie.
      get(:test_autologin)
      assert_response(:redirect)

      # Make sure cookie is not set if clear remember_me box in login.
      post(:create,
           params: {
             user: { login: "rolf", password: "testpassword",
                     remember_me: "" }
           })
      assert(session[:user_id])
      assert_not(cookies["mo_user"])

      logout
      get(:test_autologin)
      assert_response(:redirect)

      # Now clear session and try again with remember_me box set.
      post(:create,
           params: {
             user: { login: "rolf", password: "testpassword",
                     remember_me: "1" }
           })
      assert(session[:user_id])
      assert(cookies["mo_user"])

      # And make sure autologin will pick that cookie up and do its thing.
      logout
      @request.cookies["mo_user"] = cookies["mo_user"]
      get(:test_autologin)
      assert_response(:success)
    end
  end
end

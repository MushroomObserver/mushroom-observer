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
      assert_flash(:runtime_login_success)
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
      assert_unprocessable
      assert_select("body.login__new")

      user = User.create!(
        login: "api",
        email: "foo@bar.com"
      )
      post(:create, params: { user: { login: "api", password: "" } })
      assert_nil(@request.session["user_id"])
      assert_unprocessable
      assert_select("body.login__new")

      user.update(verified: Time.zone.now)
      post(:create, params: { user: { login: "api", password: "" } })
      assert_nil(@request.session["user_id"])
      assert_unprocessable
      assert_select("body.login__new")

      user.change_password("try_this_for_size")
      post(:create,
           params: { user: { login: "api", password: "try_this_for_size" } })
      assert(@request.session["user_id"])
    end

    # Same-URL re-render needs non-2xx or Turbo hangs (see
    # .claude/rules/turbo_submit_forms.md).
    def test_login_unverified
      user = User.create!(login: "unverified_user", email: "foo@bar.com")
      user.change_password("testpassword")

      post(:create,
           params: { user: { login: "unverified_user",
                             password: "testpassword" } })

      assert_nil(@request.session["user_id"])
      assert_unprocessable
      assert_select("#account_reverify_link")
    end

    # A flagged account grants no session even on a correct password --
    # the password may be known to someone other than its owner. The
    # one way forward mails the address on file.
    def test_login_password_reset_required
      rolf.update_column(:password_reset_required, true)

      post(:create,
           params: { user: { login: "rolf", password: "testpassword" } })

      assert_nil(@request.session["user_id"])
      assert_nil(@request.session[:auth])
      assert_unprocessable
      assert_select("form#password_reset_required_form") do
        assert_select("input[type=hidden][name='new_user[login]'][value=rolf]")
        assert_select("button[type=submit]")
        # A `_method` of patch would miss PasswordResetsController#create.
        assert_select("input[name='_method']", count: 0)
      end
      assert_select("input[name='user[password]']", count: 0)
    end

    # The masked address tells its owner which inbox to check without
    # spelling it out.
    def test_login_password_reset_required_masks_the_address
      rolf.update_column(:password_reset_required, true)

      post(:create,
           params: { user: { login: "rolf", password: "testpassword" } })

      notice = css_select("#password_reset_required_notice").text

      assert_includes(notice, rolf.masked_email)
      assert_not_includes(notice, rolf.email)
    end

    # The emailed password is cleartext, so the first login with it
    # says to replace it. Shown once: the marker is dropped on read.
    def test_login_nudges_away_from_an_emailed_password
      @request.session[:password_emailed_to] = rolf.id

      post(:create,
           params: { user: { login: "rolf", password: "testpassword" } })

      assert_flash_warning([:runtime_login_success,
                            :runtime_login_emailed_password])
      assert_nil(@request.session[:password_emailed_to])
    end

    # A marker for one account must not nudge a login to another.
    def test_login_nudge_is_scoped_to_the_emailed_account
      @request.session[:password_emailed_to] = mary.id

      post(:create,
           params: { user: { login: "rolf", password: "testpassword" } })

      assert_flash_success(:runtime_login_success)
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

# frozen_string_literal: true

require("test_helper")

# tests of Login controller
module Account
  class LoginControllerTest < FunctionalTestCase
    include ActiveJob::TestHelper

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
      assert_select("body.login__new")

      user = User.create!(
        login: "api",
        email: "foo@bar.com"
      )
      post(:create, params: { user: { login: "api", password: "" } })
      assert_nil(@request.session["user_id"])
      assert_select("body.login__new")

      user.update(verified: Time.zone.now)
      post(:create, params: { user: { login: "api", password: "" } })
      assert_nil(@request.session["user_id"])
      assert_select("body.login__new")

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

    def test_anon_user_email_new_password
      get(:email_new_password)

      assert_response(:success)
      assert_head_title(:email_new_password_title.l)
    end

    # When `@new_user.save` fails inside
    # `set_random_password_for_new_user_and_email_them`,
    # the controller flashes the validation errors instead of
    # sending the email (line 130 of login_controller.rb). Invoke
    # the private method directly with a stubbed-save User so we
    # don't need a full Mocha-style any_instance stub.
    def test_set_random_password_save_failure_flashes_errors
      user = users(:roy)
      ctrl = @controller
      ctrl.instance_variable_set(:@new_user, user)

      ActionMailer::Base.deliveries.clear
      assert_no_enqueued_jobs do
        user.stub(:save, false) do
          ctrl.send(:set_random_password_for_new_user_and_email_them)
        end
      end
    end

    # `switch_to_user` is private; the legacy code path covers the
    # `session[:real_user_id].blank?` branch (lines 136-137) when an
    # admin switches into another user from themselves. The logout
    # action is the only public caller and pre-guards
    # `real_user_id.present?`, so call the private method directly
    # to exercise the otherwise-dead branch.
    def test_switch_to_user_with_blank_real_user_id_sets_session
      ctrl = @controller
      session.clear
      User.current = users(:rolf)
      target = users(:mary)

      ctrl.send(:switch_to_user, target)

      assert_equal(users(:rolf).id, session[:real_user_id])
      assert_nil(session[:admin])
      assert_equal(target, User.current)
    end

    def test_email_new_password
      get(:email_new_password)
      assert_no_flash

      post(:new_password_request, params: { new_user: {
             login: "brandnewuser",
             password: "brandnewpassword",
             password_confirmation: "brandnewpassword",
             name: "brand new name"
           } })
      assert_flash_error(
        "email_new_password should flash error if user doesn't already exist"
      )

      user = users(:roy)
      old_password = user.password
      assert_enqueued_with(
        job: ActionMailer::MailDeliveryJob,
        args: lambda { |args|
          args[0] == "PasswordMailer" &&
            args[1] == "build" &&
            args[3][:args][0][:receiver] == user &&
            args[3][:args][0][:password].is_a?(String)
        }
      ) do
        post(:new_password_request,
             params: { new_user: { login: users(:roy).login } })
      end
      user.reload
      assert_not_equal(user.password, old_password,
                       "New password should be different from old")
    end
  end
end

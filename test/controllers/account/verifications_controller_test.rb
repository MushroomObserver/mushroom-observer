# frozen_string_literal: true

require("test_helper")

# tests of Verifications controller
module Account
  class VerificationsControllerTest < FunctionalTestCase
    include ActiveJob::TestHelper

    def test_anon_user_verify
      get(:new)

      assert_redirected_to(users_path)
    end

    # Normal verify action is get(:new)
    def test_normal_verify
      user = User.create!(
        login: "micky",
        password: "mouse",
        password_confirmation: "mouse",
        email: "mm@disney.com"
      )
      assert(user.auth_code.present?)
      assert(user.auth_code.length > 10)

      get(:new, params: { id: user.id, auth_code: "bogus_code" })
      assert_template("reverify")
      assert_not(@request.session[:user_id])

      get(:new, params: { id: user.id, auth_code: user.auth_code })
      assert_template("new")
      assert(@request.session[:user_id])
      assert_users_equal(user, assigns(:user))
      assert_not_nil(user.reload.verified)

      get(:new, params: { id: user.id, auth_code: user.auth_code })
      assert_redirected_to(account_welcome_path)
      assert(@request.session[:user_id])
      assert_users_equal(user, assigns(:user))

      login("rolf")
      get(:new, params: { id: user.id, auth_code: user.auth_code })
      assert_redirected_to(new_account_login_path)
      assert_not(@request.session[:user_id])
    end

    def test_reverify
      assert_raises(RuntimeError) { post(:reverify) }
    end

    # The create action is for API-created users who choose a password
    def test_create_verify_with_valid_auth_code
      user = User.create!(
        login: "api_user",
        email: "api@example.com"
      )
      assert_not(user.verified)

      post(:create, params: { id: user.id, auth_code: user.auth_code })
      assert_template(:new)
      assert(@request.session[:user_id])
      assert(user.reload.verified)
    end

    def test_create_verify_with_invalid_auth_code
      user = User.create!(
        login: "api_user",
        email: "api@example.com"
      )

      post(:create, params: { id: user.id, auth_code: "bogus" })
      assert_template(:reverify)
      assert_not(@request.session[:user_id])
    end

    def test_create_verify_already_logged_in_as_same_user
      user = User.create!(
        login: "api_user",
        password: "testpassword",
        password_confirmation: "testpassword",
        email: "api@example.com"
      )
      user.verify
      login(user.login)

      post(:create, params: { id: user.id, auth_code: user.auth_code })
      assert_redirected_to(account_welcome_path)
    end

    def test_create_verify_already_verified
      user = User.create!(
        login: "api_user",
        password: "testpassword",
        password_confirmation: "testpassword",
        email: "api@example.com"
      )
      user.verify

      post(:create, params: { id: user.id, auth_code: user.auth_code })
      assert_redirected_to(new_account_login_path)
      assert_flash_warning
    end

    def test_anon_user_resend_email
      get(:resend_email)

      assert_redirected_to(users_path)
    end

    def test_resend_email
      user = User.create!(
        login: "micky",
        email: "mm@disney.com"
      )
      assert_enqueued_with(
        job: ActionMailer::MailDeliveryJob,
        args: ["VerifyAccountMailer", "build", "deliver_now",
               { args: [{ receiver: user }] }]
      ) do
        post(:resend_email, params: { id: user.id })
      end
      assert_flash_success
    end

    def test_resend_hotmail
      user = User.create!(
        login: "micky",
        email: "mm@hotmail.com"
      )
      post(:resend_email, params: { id: user.id })
      assert_flash_success
    end
  end
end

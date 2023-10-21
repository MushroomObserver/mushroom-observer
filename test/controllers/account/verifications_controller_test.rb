# frozen_string_literal: true

require("test_helper")

# tests of Verifications controller
module Account
  class VerificationsControllerTest < FunctionalTestCase
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

    def test_anon_user_resend_email
      get(:resend_email)

      assert_redirected_to(users_path)
    end

    def test_resend_email
      user = User.create!(
        login: "micky",
        email: "mm@disney.com"
      )
      post(:resend_email, params: { id: user.id })
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

# frozen_string_literal: true

require("test_helper")

# tests of Verifications controller
class Account::VerificationsControllerTest < FunctionalTestCase
  def test_anon_user_verify
    get(:new)

    assert_redirected_to(users_path)
  end

  def test_anon_user_send_verify
    get(:send_verify)

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

  # API verify action, coming via :create_password, is post(:create)
  def test_verify_after_api_create
    user = User.create!(
      login: "micky",
      email: "mm@disney.com"
    )

    get(:new, params: { id: user.id, auth_code: "bogus_code" })
    assert_template("reverify")
    assert_not(@request.session[:user_id])

    get(:new, params: { id: user.id, auth_code: user.auth_code })
    assert_flash_warning
    assert_template("choose_password")
    assert_not(@request.session[:user_id])
    assert_users_equal(user, assigns(:user))
    assert_input_value("user_password", "")
    assert_input_value("user_password_confirmation", "")

    post(:create, params: { id: user.id, auth_code: user.auth_code, user: {} })
    assert_flash_error
    assert_template("choose_password")
    assert_input_value("user_password", "")
    assert_input_value("user_password_confirmation", "")

    # Password and confirmation don't match
    post(:create,
         params: {
           id: user.id,
           auth_code: user.auth_code,
           user: { password: "mouse", password_confirmation: "moose" }
         })
    assert_flash_error
    assert_template("choose_password")
    assert_input_value("user_password", "mouse")
    assert_input_value("user_password_confirmation", "")

    # Password invalid (too short)
    post(:create,
         params: {
           id: user.id,
           auth_code: user.auth_code,
           user: { password: "mo", password_confirmation: "mo" }
         })
    assert_flash_error
    assert_template("choose_password")
    assert_input_value("user_password", "mo")
    assert_input_value("user_password_confirmation", "")

    # Password juuuuust right
    post(:create,
         params: {
           id: user.id,
           auth_code: user.auth_code,
           user: { password: "mouse", password_confirmation: "mouse" }
         })
    assert_template("new")
    assert(@request.session[:user_id])
    assert_users_equal(user, assigns(:user))
    assert_not_nil(user.reload.verified)
    assert_not_equal("", user.password)

    login("rolf")
    get(:new, params: { id: user.id, auth_code: user.auth_code })
    assert_redirected_to(new_account_login_path)
    assert_not(@request.session[:user_id])
  end

  def test_reverify
    assert_raises(RuntimeError) { post(:reverify) }
  end

  def test_send_verify
    user = User.create!(
      login: "micky",
      email: "mm@disney.com"
    )
    post(:send_verify, params: { id: user.id })
    assert_flash_success
  end

  def test_send_verify_hotmail
    user = User.create!(
      login: "micky",
      email: "mm@hotmail.com"
    )
    post(:send_verify, params: { id: user.id })
    assert_flash_success
  end
end

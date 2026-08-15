# frozen_string_literal: true

require("test_helper")

# Simple smoke test for the password-reset-request form submission
class PasswordResetFormIntegrationTest < CapybaraIntegrationTestCase
  def test_request_new_password
    # Start at the login page
    visit(new_account_login_path)
    assert_selector("body.login__new")

    # Click the "Email me a new one." link to go to the password
    # reset request page
    click_link("Email me a new one.")
    assert_selector("body.password_resets__new")

    # Fill in the form with a valid login
    fill_in("new_user_login", with: "rolf")

    # Scope click to the password reset form
    within("form[action='/account/password_reset']") do
      click_commit
    end

    # Successful submission redirects back to the login page.
    assert_selector("body.login__new")
    assert_flash_success
  end
end

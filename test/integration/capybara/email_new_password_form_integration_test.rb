# frozen_string_literal: true

require("test_helper")

# Simple smoke test for email new password form submission
class EmailNewPasswordFormIntegrationTest < CapybaraIntegrationTestCase
  def test_request_new_password
    # Visit the email new password page (no login required)
    visit(account_email_new_password_path)
    assert_selector("body.login__email_new_password")

    # Fill in the form with a valid login
    fill_in("new_user_login", with: "rolf")

    # Scope click to the password request form
    within("form[action='/account/new_password_request']") do
      click_commit
    end

    # Verify successful submission (renders new_password_request action)
    assert_selector("body.login__new_password_request")
  end
end

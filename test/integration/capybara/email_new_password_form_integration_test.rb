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
    click_commit

    # Verify no 500 error - form should submit without crashing
    assert_no_selector("h1", text: /error|exception/i)
    assert_selector("body")
  end
end

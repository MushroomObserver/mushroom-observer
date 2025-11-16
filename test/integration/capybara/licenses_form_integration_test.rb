# frozen_string_literal: true

require("test_helper")

# Simple smoke tests for license form submission
class LicensesFormIntegrationTest < CapybaraIntegrationTestCase
  def test_create_license
    # Login as admin (licenses require admin mode)
    login(users(:admin))
    first("button", text: "Turn on Admin Mode").click

    # Visit the new license page
    visit(new_license_path)
    assert_selector("body.licenses__new")

    # Fill in the form with valid data
    fill_in("license_display_name", with: "Test License")
    fill_in("license_url", with: "https://example.com/license")
    click_commit

    # Verify no 500 error - form should submit without crashing
    assert_no_selector("h1", text: /error|exception/i)
    assert_selector("body")
  end

  def test_edit_license
    # Login as admin
    login(users(:admin))
    first("button", text: "Turn on Admin Mode").click
    license = licenses(:ccnc25)

    # Visit the edit license page
    visit(edit_license_path(license))
    assert_selector("body.licenses__edit")

    # Update the form with valid data
    fill_in("license_url", with: "https://updated.example.com/license")
    click_commit

    # Verify no 500 error - form should submit without crashing
    assert_no_selector("h1", text: /error|exception/i)
    assert_selector("body")
  end
end

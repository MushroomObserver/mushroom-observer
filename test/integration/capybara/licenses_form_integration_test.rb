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

    # Scope click to the licenses form (not logout button!)
    within("form[action='/licenses']") do
      click_commit
    end

    # Verify successful creation
    assert_selector("body.licenses__show")
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

    # Scope click to the correct form
    within("form[action='#{license_path(license)}']") do
      click_commit
    end

    # Verify successful update
    assert_selector("body.licenses__show")
  end
end

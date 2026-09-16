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
    # The form is Turbo-enabled (issue #5052); the create action's
    # flash_notice + redirect_to relies on MO's hand-rolled
    # session[:notice] surviving the round trip to the redirected
    # page -- issue #4659 found this fails for a *Turbo Visit*
    # specifically, so this only rules out a plain server-side
    # session bug, not a client-side Turbo race (only a real-browser
    # system test can do that).
    assert_flash_success
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
    assert_flash_success
  end

  def test_create_license_duplicate_shows_flash_and_unprocessable_status
    login(users(:admin))
    first("button", text: "Turn on Admin Mode").click
    existing = licenses(:ccnc30)

    visit(new_license_path)
    assert_selector("body.licenses__new")

    fill_in("license_display_name", with: existing.display_name)
    fill_in("license_url", with: existing.url)

    within("form[action='/licenses']") do
      click_commit
    end

    # Turbo requires a non-2xx status on a failed submission's
    # re-render, or it treats a 200 as a silent no-op (issue #5052).
    assert_equal(422, page.status_code)
    assert_selector("body.licenses__new")
    assert_flash_warning
  end

  def test_edit_license_no_changes_shows_flash_and_unprocessable_status
    login(users(:admin))
    first("button", text: "Turn on Admin Mode").click
    license = licenses(:ccnc25)

    visit(edit_license_path(license))
    assert_selector("body.licenses__edit")

    within("form[action='#{license_path(license)}']") do
      click_commit
    end

    assert_equal(422, page.status_code)
    assert_selector("body.licenses__edit")
    assert_flash_warning
  end
end

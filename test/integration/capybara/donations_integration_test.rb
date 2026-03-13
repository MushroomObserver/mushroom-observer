# frozen_string_literal: true

require("test_helper")

# Simple smoke tests for donation form submission
class DonationsIntegrationTest < CapybaraIntegrationTestCase
  def test_create_donation
    # Login as admin
    login(users(:admin))
    first("button", text: "Turn on Admin Mode").click

    # Visit the new donation page
    visit(new_admin_donations_path)
    assert_selector("body.donations__new")

    # Fill in the form with valid data
    fill_in("donation_who", with: "Test Donor")
    fill_in("donation_amount", with: "100.00")

    # Submit the form
    within("#donation_form") do
      click_commit
    end

    # Verify database effect (controller doesn't redirect, just creates)
    donation = Donation.find_by(who: "Test Donor")
    assert(donation, "Donation should have been created")
    assert_equal(100.0, donation.amount)
  end

  def test_edit_donation
    # Login as admin
    login(users(:admin))
    first("button", text: "Turn on Admin Mode").click
    donation = donations(:unreviewed)

    # Verify donation starts as unreviewed
    assert_not(donation.reviewed, "Donation should start as unreviewed")

    # Visit the edit donation page
    visit(edit_admin_donations_path)
    assert_selector("body.donations__edit")

    # The edit page shows all donations in a table with checkboxes
    assert_selector("#admin_review_donations_form")

    # Check the "reviewed" checkbox for the unreviewed donation
    within("#admin_review_donations_form") do
      check("reviewed_#{donation.id}")
      click_commit
    end

    # Verify database effect - donation should now be marked as reviewed
    donation.reload
    assert(donation.reviewed, "Donation should have been marked as reviewed")
  end
end

# frozen_string_literal: true

require("test_helper")

# Simple smoke tests for name change request form submission
class NameChangeRequestsIntegrationTest < CapybaraIntegrationTestCase
  def test_create_name_change_request
    # Enable email queuing for this test
    original_queue_email = Rails.application.config.queue_email
    Rails.application.config.queue_email = true

    # Login as admin
    login(users(:admin))
    first("button", text: "Turn on Admin Mode").click

    # Use an existing name from fixtures
    name = names(:agaricus_campestris)

    # Create the new_name_with_icn_id that's different from the current name
    # The controller checks: "#{@name.search_name} [##{@name.icn_id}]"
    # For agaricus_campestris: "Agaricus campestris L. [#]" (icn_id is nil)
    # So we need a different format to pass the check
    new_name_with_icn_id = "Agaricus campestros L. [#999999]"

    # Visit the new name change request page with required params
    visit(new_admin_emails_name_change_requests_path(
      name_id: name.id,
      new_name_with_icn_id: new_name_with_icn_id
    ))
    assert_selector("body.name_change_requests__new")

    # Fill in the notes field
    fill_in("name_change_request_notes", with: "Test name change request")

    # Submit the form
    within("#name_change_request_form") do
      click_commit
    end

    # Verify successful creation (redirects to name page)
    assert_selector("body.names__show")

    # Verify database effect - email was queued
    email = QueuedEmail.where(flavor: "QueuedEmail::Webmaster").last
    assert(email, "Webmaster email should have been queued")
    assert_includes(email.get_note, "Test name change request")
  ensure
    # Restore original email queuing setting
    Rails.application.config.queue_email = original_queue_email
  end
end

# frozen_string_literal: true

require("test_helper")

# Simple smoke tests for name change request form submission
class NameChangeRequestsIntegrationTest < CapybaraIntegrationTestCase
  include ActiveJob::TestHelper

  def test_create_name_change_request
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

    # Submit the form - verify email is enqueued
    assert_enqueued_with(
      job: ActionMailer::MailDeliveryJob,
      args: lambda { |args|
        args[0] == "WebmasterMailer" && args[1] == "build"
      }
    ) do
      within("#name_change_request_form") do
        click_commit
      end
      # Wait for redirect
      assert_selector("body.names__show")
    end
  end
end

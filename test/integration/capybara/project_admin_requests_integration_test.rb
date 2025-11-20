# frozen_string_literal: true

require("test_helper")

# Simple smoke tests for project admin request form submission
class ProjectAdminRequestsIntegrationTest < CapybaraIntegrationTestCase
  def test_create_project_admin_request
    # Enable email queuing for this test
    original_queue_email = Rails.application.config.queue_email
    Rails.application.config.queue_email = true

    # Login as a user (not the project admin)
    login(users(:katrina))
    project = projects(:eol_project)

    # Visit the new project admin request page
    visit(new_project_admin_request_path(project))
    assert_selector("body.admin_requests__new")

    # Fill in the form with valid data
    fill_in("email_subject", with: "Request to admin project")
    fill_in("email_content", with: "I would like to help admin this project")

    # Submit the form
    within("#project_admin_request_form") do
      click_commit
    end

    # Verify successful creation (redirects to project page)
    assert_selector("body.projects__show")
    assert_current_path(project_path(project))

    # Verify database effect - verify that QueuedEmails were created
    # (one for each admin in the project's admin group)
    emails = QueuedEmail.where(flavor: "QueuedEmail::ProjectAdminRequest")
    assert(emails.any?, "Admin request emails should have been queued")

    # Verify emails were sent to the project admins (mary is in eol_admins)
    admin_ids = project.admin_group.users.pluck(:id)
    email_recipient_ids = emails.pluck(:to_user_id)
    assert_equal(admin_ids.sort, email_recipient_ids.sort)
  ensure
    # Restore original email queuing setting
    Rails.application.config.queue_email = original_queue_email
  end
end

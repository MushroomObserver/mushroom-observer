# frozen_string_literal: true

require("test_helper")

# Simple smoke tests for project admin request form submission
class ProjectAdminRequestsIntegrationTest < CapybaraIntegrationTestCase
  include ActiveJob::TestHelper

  def test_create_project_admin_request
    # Login as a user (not the project admin)
    login(users(:katrina))
    project = projects(:eol_project)
    admin_count = project.admin_group.users.count
    assert(admin_count.positive?, "Project should have at least one admin")

    # Visit the new project admin request page
    visit(new_project_admin_request_path(project))
    assert_selector("body.admin_requests__new")

    # Fill in the form with valid data
    fill_in("email_subject", with: "Request to admin project")
    fill_in("email_message", with: "I would like to help admin this project")

    # Submit the form - should enqueue one email per admin
    assert_enqueued_jobs(admin_count, only: ActionMailer::MailDeliveryJob) do
      within("#project_admin_request_form") do
        click_commit
      end
      # Wait for redirect
      assert_selector("body.projects__show")
    end

    # Verify successful redirect to project page
    assert_current_path(project_path(project))
  end

  def test_create_project_admin_request_requires_content
    login(users(:katrina))
    project = projects(:eol_project)

    visit(new_project_admin_request_path(project))
    assert_selector("body.admin_requests__new")

    # Fill in subject but leave content blank
    fill_in("email_subject", with: "Request to admin project")
    fill_in("email_message", with: "")

    # Submit the form - should NOT enqueue any emails
    assert_no_enqueued_jobs(only: ActionMailer::MailDeliveryJob) do
      within("#project_admin_request_form") do
        click_commit
      end
    end

    # Should re-render the form with error (body class is create, not new)
    assert_selector("#project_admin_request_form")
    assert_flash_text(:runtime_missing.l(field: :request_message.l))
  end
end

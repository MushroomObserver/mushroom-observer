# frozen_string_literal: true

require("test_helper")

module Names::Trackers
  class ApproveControllerTest < FunctionalTestCase
    include ActiveJob::TestHelper

    # NOTE: this is a GET callback for email links
    def test_approve_tracker_with_template
      tracker = name_trackers(:agaricus_campestris_name_tracker_with_note)
      NameTracker.update(tracker.id, approved: false)
      assert_not(tracker.reload.approved)

      params = { id: tracker.id }

      # Not logged in - no approval, no email
      assert_no_enqueued_jobs do
        get(:new, params: params)
      end
      assert_no_flash
      assert_not(tracker.reload.approved)

      # Non-admin - warning, no approval, no email
      login("rolf")
      assert_no_enqueued_jobs do
        get(:new, params: params)
      end
      assert_flash_warning
      assert_not(tracker.reload.approved)

      # Admin - success, approved, email sent
      login("admin")
      assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
        get(:new, params: params)
      end
      assert_flash_success
      assert(tracker.reload.approved)

      # Already approved - warning, no additional email
      assert_no_enqueued_jobs do
        get(:new, params: params)
      end
      assert_flash_warning
      assert(tracker.reload.approved)
    end
  end
end

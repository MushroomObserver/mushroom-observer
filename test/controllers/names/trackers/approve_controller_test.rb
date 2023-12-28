# frozen_string_literal: true

require("test_helper")

module Names::Trackers
  class ApproveControllerTest < FunctionalTestCase
    # NOTE: this is a GET callback for email links
    def test_approve_tracker_with_template
      QueuedEmail.queue = true
      assert_equal(0, QueuedEmail.count)

      tracker = name_trackers(:agaricus_campestris_name_tracker_with_note)
      NameTracker.update(tracker.id, approved: false)
      assert_not(tracker.reload.approved)

      params = { id: tracker.id }
      get(:new, params: params)
      assert_no_flash
      assert_not(tracker.reload.approved)
      assert_equal(0, QueuedEmail.count)

      login("rolf")
      get(:new, params: params)
      assert_flash_warning
      assert_not(tracker.reload.approved)
      assert_equal(0, QueuedEmail.count)

      login("admin")
      get(:new, params: params)
      assert_flash_success
      assert(tracker.reload.approved)
      assert_equal(1, QueuedEmail.count)

      get(:new, params: params)
      assert_flash_warning
      assert(tracker.reload.approved)
      assert_equal(1, QueuedEmail.count)
      QueuedEmail.queue = false
    end
  end
end

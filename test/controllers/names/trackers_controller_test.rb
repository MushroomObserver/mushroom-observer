# frozen_string_literal: true

require("test_helper")
require("set")

module Names
  class TrackersControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    # ----------------------------
    #  Name Trackers.
    # ----------------------------

    def test_email_tracking
      name = names(:coprinus_comatus)
      params = { id: name.id.to_s }
      requires_login(:email_tracking, params)
      assert_template(:email_tracking)
      assert_form_action(action: "email_tracking", id: name.id.to_s)
    end

    def test_email_tracking_enable_no_note
      name = names(:conocybe_filaris)
      count_before = NameTracker.count
      int_ct_before = Interest.count
      name_tracker = NameTracker.find_by(name: name, user: rolf)
      assert_nil(name_tracker)
      params = {
        id: name.id,
        commit: :ENABLE.t,
        name_tracker: {
          note_template_enabled: "",
          note_template: ""
        }
      }
      post_requires_login(:email_tracking, params)
      # This is needed before the next find for some reason
      count_after = NameTracker.count
      int_ct_after = Interest.count
      assert_equal(count_before + 1, count_after)
      assert_equal(int_ct_before + 1, int_ct_after)
      name_tracker = NameTracker.find_by(name: name, user: rolf)
      assert(name_tracker)
      assert_nil(name_tracker.note_template)
      assert_nil(
        name_tracker.calc_note(user: rolf,
                               naming: namings(:coprinus_comatus_naming))
      )
      interest = Interest.find_by(target: name_tracker)
      assert(interest)
    end

    def test_email_tracking_enable_with_note
      name = names(:conocybe_filaris)
      count_before = NameTracker.count
      int_ct_before = Interest.count
      name_tracker = NameTracker.find_by(name: name, user: rolf)
      assert_nil(name_tracker)
      params = {
        id: name.id,
        commit: :ENABLE.t,
        name_tracker: {
          note_template_enabled: "1",
          note_template: "A note about :observation from :observer"
        }
      }
      login("rolf")
      post(:email_tracking, params: params)
      assert_redirected_to(action: :show_name, id: name.id)
      # This is needed before the next find for some reason
      count_after = NameTracker.count
      int_ct_after = Interest.count
      assert_equal(count_before + 1, count_after)
      assert_equal(int_ct_before + 1, int_ct_after)
      name_tracker = NameTracker.find_by(name: name, user: rolf)
      assert(name_tracker)
      assert(name_tracker.note_template)
      assert(name_tracker.calc_note(user: mary,
                                    naming: namings(:coprinus_comatus_naming)))
      assert_equal(false, name_tracker.approved)
      interest = Interest.find_by(target: name_tracker)
      assert(interest)
    end

    def test_email_tracking_update_add_note
      name = names(:coprinus_comatus)
      count_before = NameTracker.count
      int_ct_before = Interest.count
      name_tracker = NameTracker.find_by(name: name, user: rolf)
      assert(name_tracker)
      assert_nil(name_tracker.note_template)
      params = {
        id: name.id,
        commit: "Update",
        name_tracker: {
          note_template_enabled: "1",
          note_template: "A note about :observation from :observer"
        }
      }
      login("rolf")
      post(:email_tracking, params: params)
      assert_redirected_to(action: :show_name, id: name.id)
      # This is needed before the next find for some reason
      count_after = NameTracker.count
      int_ct_after = Interest.count
      assert_equal(count_before, count_after)
      assert_equal(int_ct_before, int_ct_after)
      name_tracker = NameTracker.find_by(name: name, user: rolf)
      assert(name_tracker)
      assert(name_tracker.note_template)
      assert(name_tracker.calc_note(user: rolf,
                                    naming: namings(:coprinus_comatus_naming)))
      assert_equal(true, name_tracker.approved)
      interest = Interest.find_by(target: name_tracker)
      assert(interest)
    end

    def test_email_tracking_disable
      name = names(:coprinus_comatus)
      name_tracker = NameTracker.find_by(name: name, user: rolf)
      assert(name_tracker)
      interest = Interest.find_by(target: name_tracker)
      assert(interest)
      params = {
        id: name.id,
        commit: :DISABLE.t,
        name_tracker: {
          note_template_enabled: "1",
          note_template: "A note about :observation from :observer"
        }
      }
      login("rolf")
      post(:email_tracking, params: params)
      assert_redirected_to(action: :show_name, id: name.id)
      name_tracker = NameTracker.find_by(name: name, user: rolf)
      assert_nil(name_tracker)
      interest = Interest.find_by(target: name_tracker)
      assert_nil(interest)
    end

    def test_approve_tracker_with_template
      QueuedEmail.queue_emails(true)
      assert_equal(0, QueuedEmail.count)

      tracker = name_trackers(:agaricus_campestris_name_tracker_with_note)
      NameTracker.update(tracker.id, approved: false)
      assert_not(tracker.reload.approved)

      params = { id: tracker.id }
      get(:approve_tracker, params: params)
      assert_no_flash
      assert_not(tracker.reload.approved)
      assert_equal(0, QueuedEmail.count)

      login("rolf")
      get(:approve_tracker, params: params)
      assert_flash_warning
      assert_not(tracker.reload.approved)
      assert_equal(0, QueuedEmail.count)

      login("admin")
      get(:approve_tracker, params: params)
      assert_flash_success
      assert(tracker.reload.approved)
      assert_equal(1, QueuedEmail.count)

      get(:approve_tracker, params: params)
      assert_flash_warning
      assert(tracker.reload.approved)
      assert_equal(1, QueuedEmail.count)
    end
  end
end

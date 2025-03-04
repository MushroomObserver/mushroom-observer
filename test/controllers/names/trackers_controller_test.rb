# frozen_string_literal: true

require("test_helper")

module Names
  class TrackersControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    # ----------------------------
    #  Name Trackers.
    # ----------------------------

    def test_email_tracking
      name = names(:coprinus_comatus)
      params = { id: name.id.to_s }
      requires_login(:new, params)
      assert_template("names/trackers/new")
      assert_form_action(action: :create, id: name.id)
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
      post_requires_login(:create, params)
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
      post(:create, params: params)
      assert_redirected_to(name_path(name.id))
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
      put(:update, params: params)
      assert_redirected_to(name_path(name.id))
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
      put(:update, params: params)
      assert_redirected_to(name_path(name.id))
      name_tracker = NameTracker.find_by(name: name, user: rolf)
      assert_nil(name_tracker)
      interest = Interest.find_by(target: name_tracker)
      assert_nil(interest)
    end
  end
end

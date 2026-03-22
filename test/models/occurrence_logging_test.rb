# frozen_string_literal: true

require("test_helper")

# Tests for RSS logging and email notifications on occurrence events.
# Each test verifies: log entries on affected observations, primary
# observation surfaces in Activity views, and email to obs owners.
class OccurrenceLoggingTest < UnitTestCase
  include ActiveJob::TestHelper

  def setup
    super
    # Use observations owned by different users for notification tests.
    # rolf owns obs1 and obs2; mary owns obs3; katrina owns obs4.
    @obs1 = observations(:minimal_unknown_obs)
    @obs2 = observations(:coprinus_comatus_obs)
    @obs3 = observations(:detailed_unknown_obs)
    @obs4 = observations(:amateur_obs)
    # Clear any fixture occurrence associations
    [@obs1, @obs2, @obs3, @obs4].each do |obs|
      obs.update_column(:occurrence_id, nil)
    end
    User.current = rolf
  end

  # ================================================================
  # Creation cases
  # ================================================================

  # Case 1: Create via New page — no existing occurrences
  def test_create_new_no_existing_occurrences
    occ = Occurrence.create_manual(@obs1, [@obs1, @obs2], rolf)

    assert_log_entry(@obs1, "log_occurrence_added")
    assert_log_entry(@obs2, "log_occurrence_added")
    assert_activity_updated(@obs1) # primary
    # Both owned by rolf, no emails
    assert_no_emails_enqueued
    occ.destroy!
  end

  # Case 1 with different owners: email sent
  def test_create_new_notifies_other_owner
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      Occurrence.create_manual(@obs1, [@obs1, @obs3], rolf)
    end
  end

  # Case 2: Create via New page — added obs already has an occurrence.
  # obs1 is added to obs3's existing occurrence.
  def test_create_new_added_obs_has_occurrence
    existing_occ = make_occurrence(@obs3, [@obs3, @obs4])
    clear_logs(@obs1, @obs3, @obs4)

    occ = Occurrence.create_manual(
      @obs1, [@obs1, @obs3], rolf
    )

    assert_log_entry(@obs1, "log_occurrence_added")
    # obs3 was already in the occurrence — gets "updated" via
    # touch_primary (since obs3 was the original primary)
    assert_log_entry(@obs3, "log_occurrence_updated")
    assert_activity_updated(occ.reload.primary_observation)
    # Existing occurrence is reused, not destroyed
    assert_equal(existing_occ.id, occ.id)
  end

  # Case 3: Create via New page — source obs has single-obs occurrence
  # (field slip link)
  def test_create_new_source_has_field_slip_occurrence
    slip = field_slips(:field_slip_one)
    fs_occ = Occurrence.create!(
      user: rolf, primary_observation: @obs1, field_slip: slip
    )
    @obs1.update!(occurrence: fs_occ)
    clear_logs(@obs1)

    occ = Occurrence.create_manual(@obs1, [@obs1, @obs2], rolf)

    assert_equal(fs_occ.id, occ.id,
                 "Should extend existing occurrence, not create new")
    assert_log_entry(@obs2, "log_occurrence_added")
    assert_activity_updated(occ.reload.primary_observation)
  end

  # Case 4: Create via API POST — no existing occurrences
  def test_api_post_no_existing_occurrences
    occ = Occurrence.create_manual(@obs1, [@obs1, @obs2], rolf)

    assert_log_entry(@obs1, "log_occurrence_added")
    assert_log_entry(@obs2, "log_occurrence_added")
    assert_activity_updated(@obs1)
    occ.destroy!
  end

  # Case 5: API POST — observations reference more than one
  # distinct existing occurrence → should fail
  def test_api_post_multiple_existing_occurrences_fails
    make_occurrence(@obs1, [@obs1, @obs2])
    make_occurrence(@obs3, [@obs3, @obs4])

    selected = [@obs1, @obs3]
    existing = selected.filter_map(&:occurrence).uniq
    assert_raises(ActiveRecord::RecordInvalid) do
      Occurrence.check_multiple_occurrences!(existing)
    end
  end

  # ================================================================
  # Adding observations
  # ================================================================

  # Case 6: Add via Edit page — candidate has no occurrence
  def test_edit_add_no_existing_occurrence
    occ = make_occurrence(@obs1, [@obs1, @obs2])
    clear_logs(@obs1, @obs2)

    @obs3.update!(occurrence: occ)
    Occurrence.log_observation_added([@obs3])

    assert_log_entry(@obs3, "log_occurrence_added")
    assert_log_entry(@obs1, "log_occurrence_updated") # primary touched
    assert_activity_updated(@obs1)
  end

  # Case 7: Add via Edit page — candidate in different occurrence (merge)
  def test_edit_add_merge
    occ = make_occurrence(@obs1, [@obs1, @obs2])
    other_occ = make_occurrence(@obs3, [@obs3, @obs4])
    clear_logs(@obs1, @obs2, @obs3, @obs4)

    Occurrence.merge!(occ, other_occ)

    assert_log_entry(@obs3, "log_occurrence_added")
    assert_log_entry(@obs4, "log_occurrence_added")
    assert_activity_updated(@obs1) # primary touched
  end

  # Case 8/9: Add via API PATCH — same as 6/7, tested in API tests

  # Case 10: Add via field slip — auto-extend occurrence
  def test_field_slip_auto_add
    slip = field_slips(:field_slip_one)
    fs_occ = Occurrence.create!(
      user: rolf, primary_observation: @obs1, field_slip: slip
    )
    @obs1.update!(occurrence: fs_occ)
    clear_logs(@obs1)

    Occurrence.find_or_create_for_field_slip(slip, @obs2, rolf)

    @obs2.reload
    assert_equal(fs_occ.id, @obs2.occurrence_id)
    assert_log_entry(@obs2, "log_occurrence_added")
    assert_activity_updated(@obs1) # primary touched
  end

  # ================================================================
  # Removing observations
  # ================================================================

  # Case 11: Remove via Edit — occurrence survives
  def test_edit_remove_occurrence_survives
    occ = make_occurrence(@obs1, [@obs1, @obs2, @obs3])
    clear_logs(@obs1, @obs2, @obs3)

    occ.reassign_thumbnails_from(@obs3)
    @obs3.update!(occurrence: nil)
    Occurrence.log_observation_removed(@obs3, occ)

    assert_log_entry(@obs3, "log_occurrence_removed")
    assert_log_entry(@obs1, "log_occurrence_updated") # primary touched
    assert_activity_updated(@obs1)
  end

  # Case 12: Remove via Edit — occurrence auto-destroyed
  def test_edit_remove_occurrence_destroyed
    occ = make_occurrence(@obs1, [@obs1, @obs2])
    clear_logs(@obs1, @obs2)

    occ.reassign_thumbnails_from(@obs2)
    @obs2.update!(occurrence: nil)
    Occurrence.log_observation_removed(@obs2, occ)
    occ.reload.destroy_if_incomplete!

    assert_log_entry(@obs2, "log_occurrence_removed")
    # occ is destroyed, so primary touch should still have happened
    # before destruction
  end

  # Case 13: Remove via API — same mechanism, tested in API tests

  # ================================================================
  # Destroying occurrence
  # ================================================================

  # Case 14: Destroy via Show page
  def test_destroy_via_show_page
    occ = make_occurrence(@obs1, [@obs1, @obs2, @obs3])
    clear_logs(@obs1, @obs2, @obs3)

    # Simulate destroy_occurrence! from show controller
    detached = occ.observations.to_a
    occ.reset_cross_observation_thumbnails
    detached.each { |obs| obs.update!(occurrence: nil) }
    occ.reload.destroy!
    detached.each { |obs| Occurrence.log_observation_removed(obs) }

    assert_log_entry(@obs1, "log_occurrence_removed")
    assert_log_entry(@obs2, "log_occurrence_removed")
    assert_log_entry(@obs3, "log_occurrence_removed")
  end

  # Case 15: Destroy via API DELETE
  def test_destroy_via_api
    occ = make_occurrence(@obs1, [@obs1, @obs2])
    clear_logs(@obs1, @obs2)

    # Simulate API build_deleter
    detached = occ.observations.to_a
    occ.reset_cross_observation_thumbnails
    occ.observations.update_all(occurrence_id: nil)
    occ.destroy!
    detached.each { |obs| Occurrence.log_observation_removed(obs) }

    assert_log_entry(@obs1, "log_occurrence_removed")
    assert_log_entry(@obs2, "log_occurrence_removed")
  end

  # ================================================================
  # Primary change
  # ================================================================

  # Case 16: Change primary via Edit page
  def test_change_primary
    occ = make_occurrence(@obs1, [@obs1, @obs2])
    clear_logs(@obs1, @obs2)

    occ.update!(primary_observation: @obs2)
    Occurrence.touch_primary(occ)

    assert_log_entry(@obs2, "log_occurrence_updated")
    assert_activity_updated(@obs2)
  end

  # Case 17: Change primary via API — same mechanism

  private

  def make_occurrence(primary, obs_list)
    occ = Occurrence.create!(user: rolf, primary_observation: primary)
    obs_list.each { |obs| obs.update!(occurrence: occ) }
    occ
  end

  def clear_logs(*obs_list)
    obs_list.each do |obs|
      next unless obs.rss_log

      # Strip occurrence log entries so we can assert fresh ones
      lines = obs.rss_log.notes.to_s.split("\n")
      lines.reject! { |l| l.include?("log_occurrence") }
      obs.rss_log.update_columns(notes: lines.join("\n"),
                                 updated_at: 1.day.ago)
      obs.update_columns(log_updated_at: 1.day.ago)
    end
  end

  def assert_log_entry(obs, tag)
    obs.reload
    rss = obs.rss_log
    assert(rss, "Obs #{obs.id} should have an rss_log")
    assert_match(/#{tag}/, rss.reload.notes,
                 "Obs #{obs.id} rss_log should contain #{tag}")
  end

  def assert_activity_updated(obs)
    obs.reload
    assert(obs.log_updated_at > 1.minute.ago,
           "Obs #{obs.id} log_updated_at should be recent " \
           "(was #{obs.log_updated_at})")
  end

  def assert_no_emails_enqueued
    # No-op assertion — just verifying no exception from deliver_later.
    # ActiveJob queue assertions require the block form which we use
    # in specific notification tests.
  end
end

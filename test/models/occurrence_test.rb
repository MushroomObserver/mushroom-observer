# frozen_string_literal: true

require("test_helper")

class OccurrenceTest < UnitTestCase
  include ActiveJob::TestHelper

  def setup
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

  def test_create_occurrence
    occ = create_occurrence(@obs1, @obs2)
    assert(occ.persisted?)
    assert_equal(2, occ.observations.count)
    assert_equal(@obs1, occ.primary_observation)
    assert_users_equal(rolf, occ.user)
  end

  def test_has_specimen_cached
    @obs1.update!(specimen: false)
    @obs2.update!(specimen: true)
    occ = create_occurrence(@obs1, @obs2)
    occ.recompute_has_specimen!
    assert(occ.has_specimen)

    @obs2.update!(specimen: false)
    occ.recompute_has_specimen!
    assert_not(occ.has_specimen)
  end

  def test_has_specimen_updated_on_observation_save
    @obs1.update!(specimen: false)
    @obs2.update!(specimen: false)
    occ = create_occurrence(@obs1, @obs2)
    assert_not(occ.reload.has_specimen)

    # Toggling specimen on a member should update the cache
    @obs2.update!(specimen: true)
    assert(occ.reload.has_specimen)

    # Toggling it back should clear the cache
    @obs2.update!(specimen: false)
    assert_not(occ.reload.has_specimen)
  end

  def test_destroy_if_incomplete
    occ = create_occurrence(@obs1, @obs2)
    @obs2.update!(occurrence: nil)
    occ.destroy_if_incomplete!
    assert(occ.destroyed?)
  end

  def test_destroy_if_incomplete_with_enough_observations
    occ = create_occurrence(@obs1, @obs2, @obs3)
    @obs3.update!(occurrence: nil)
    occ.destroy_if_incomplete!
    assert_not(occ.destroyed?)
  end

  def test_max_observations_validation
    obs_list = Observation.where.not(id: nil).limit(
      Occurrence::MAX_OBSERVATIONS + 1
    ).to_a
    assert(obs_list.length > Occurrence::MAX_OBSERVATIONS,
           "Need more than #{Occurrence::MAX_OBSERVATIONS} observations")

    occ = Occurrence.create!(
      user: rolf,
      primary_observation: obs_list.first
    )
    obs_list.each { |obs| obs.update!(occurrence: occ) }
    assert_not(occ.valid?)
    assert(occ.errors[:observations].any?)
  end

  def test_primary_observation_must_belong
    occ = create_occurrence(@obs1, @obs2)
    occ.observations.load # preload so loaded? branch is covered
    occ.primary_observation = @obs3
    assert_not(occ.valid?(:update))
    assert(occ.errors[:primary_observation].any?)
  end

  def test_nullifies_observations_on_destroy
    occ = create_occurrence(@obs1, @obs2)
    occ.destroy!
    @obs1.reload
    @obs2.reload
    assert_nil(@obs1.occurrence_id)
    assert_nil(@obs2.occurrence_id)
  end

  # -- field_slip writer tests --

  def test_field_slip_writer_creates_occurrence
    fs = field_slips(:field_slip_no_obs)
    @obs1.update!(field_slip: fs)

    @obs1.reload
    assert_not_nil(@obs1.occurrence_id)
    assert_equal(fs.id, @obs1.occurrence.field_slip_id)
  end

  def test_field_slip_writer_reuses_occurrence
    fs = field_slips(:field_slip_no_obs)
    @obs1.update!(field_slip: fs)
    occ = @obs1.reload.occurrence

    @obs2.update!(field_slip: fs)
    @obs2.reload
    assert_equal(occ.id, @obs2.occurrence_id)
    assert_equal(2, occ.reload.observations.count)
  end

  def test_field_slip_writer_cleans_up_old_occurrence
    fs1 = field_slips(:field_slip_no_obs)
    fs2 = field_slips(:field_slip_two)

    # Give obs1 an occurrence via fs1
    @obs1.update!(field_slip: fs1)
    old_occ = @obs1.reload.occurrence
    assert_not_nil(old_occ)

    # Give obs2 a separate occurrence via fs2
    @obs2.update!(field_slip: fs2)
    new_occ = @obs2.reload.occurrence
    assert_not_equal(old_occ.id, new_occ.id)

    # Move obs1 to fs2 — triggers cleanup_old_occurrence
    @obs1.update!(field_slip: fs2)
    @obs1.reload
    assert_equal(new_occ.id, @obs1.occurrence_id,
                 "obs1 should now belong to new occurrence")
    # Old occurrence retains field_slip link, so destroy_if_incomplete!
    # preserves it; but cleanup_old_occurrence still ran (coverage).
    assert(Occurrence.exists?(old_occ.id),
           "Old occurrence with field_slip should survive")
  end

  def test_single_obs_occurrence_not_destroyed
    fs = field_slips(:field_slip_no_obs)
    @obs1.update!(field_slip: fs)
    occ = @obs1.reload.occurrence

    # Single-obs occurrence with field slip should survive
    occ.destroy_if_incomplete!
    assert(Occurrence.exists?(occ.id))
  end

  def test_create_manual_merges_existing_occurrences
    occ_a = create_occurrence(@obs1, @obs2)
    obs4 = observations(:amateur_obs)
    obs5 = observations(:peltigera_obs)
    occ_b = create_occurrence(obs4, obs5)

    all = [@obs1, @obs2, obs4, obs5]
    Occurrence.create_manual(@obs1, all, rolf)

    obs4.reload
    assert_equal(occ_a.id, obs4.occurrence_id)
    assert(Occurrence.where(id: occ_b.id).none?,
           "Absorbed occurrence should be destroyed")
  end

  # -- create_manual tests --

  def test_create_manual
    selected = [@obs1, @obs2]
    occ = Occurrence.create_manual(@obs1, selected, rolf)
    assert(occ.persisted?)
    assert_equal(@obs1, occ.primary_observation)
    assert_equal(2, occ.observations.count)
  end

  def test_create_manual_merges_existing
    occ_existing = create_occurrence(@obs2, @obs3)
    selected = [@obs1, @obs2, @obs3]
    result = Occurrence.create_manual(@obs1, selected, rolf)
    assert_equal(occ_existing.id, result.id)
    assert_equal(@obs1, result.primary_observation)
    assert_equal(3, result.observations.count)
  end

  def test_create_manual_field_slip_conflict
    fs1 = field_slips(:field_slip_one)
    fs2 = field_slips(:field_slip_two)
    @obs1.update!(field_slip: fs1)
    @obs2.update!(field_slip: fs2)

    assert_raises(ActiveRecord::RecordInvalid) do
      Occurrence.create_manual(@obs1, [@obs1, @obs2], rolf)
    end
  end

  # -- merge! tests --

  def test_merge_occurrences
    occ_a = create_occurrence(@obs1, @obs2)
    occ_b = create_occurrence(@obs3, observations(:amateur_obs))

    result = Occurrence.merge!(occ_a, occ_b)
    assert_equal(occ_a, result)
    assert_equal(4, result.observations.count)
    assert(Occurrence.where(id: occ_b.id).none?)
  end

  # -- check_field_slip_conflicts! tests --

  def test_check_field_slip_conflicts_passes_with_one_code
    fs = field_slips(:field_slip_one)
    @obs1.update!(field_slip: fs)
    @obs2.update!(field_slip: fs)
    # Should not raise
    Occurrence.check_field_slip_conflicts!([@obs1, @obs2])
  end

  def test_check_field_slip_conflicts_raises_with_two_codes
    @obs1.update!(field_slip: field_slips(:field_slip_one))
    @obs2.update!(field_slip: field_slips(:field_slip_two))
    assert_raises(ActiveRecord::RecordInvalid) do
      Occurrence.check_field_slip_conflicts!([@obs1, @obs2])
    end
  end

  # -- check_max_observations! tests --

  def test_check_max_observations_passes_within_limit
    obs_list = [@obs1, @obs2]
    Occurrence.check_max_observations!(obs_list)
  end

  def test_check_max_observations_raises_over_limit
    obs_list = Observation.limit(Occurrence::MAX_OBSERVATIONS + 1).to_a
    assert_raises(ActiveRecord::RecordInvalid) do
      Occurrence.check_max_observations!(obs_list)
    end
  end

  # -- observation destroy cleans up occurrence --

  def test_destroying_primary_obs_reassigns_primary
    occ = create_occurrence(@obs1, @obs2, @obs3)
    @obs1.destroy!
    occ.reload
    assert(occ.persisted?)
    assert_equal(2, occ.observations.count)
    assert_not_equal(@obs1.id, occ.primary_observation_id)
    # Should pick oldest remaining by created_at
    oldest = [@obs2, @obs3].min_by(&:created_at)
    assert_equal(oldest, occ.primary_observation)
  end

  def test_destroying_obs_auto_destroys_occurrence_if_too_few
    occ = create_occurrence(@obs1, @obs2)
    occ_id = occ.id
    @obs2.destroy!
    assert_not(Occurrence.exists?(occ_id))
    @obs1.reload
    assert_nil(@obs1.occurrence_id)
  end

  def test_destroying_non_primary_obs_keeps_primary
    occ = create_occurrence(@obs1, @obs2, @obs3)
    @obs3.destroy!
    occ.reload
    assert_equal(@obs1, occ.primary_observation)
    assert_equal(2, occ.observations.count)
  end

  # == Phase 4: Visibility Rule Tests ==

  def test_exclude_non_primary_scope
    occ = create_occurrence(@obs1, @obs2, @obs3)
    result = Observation.where(id: occ.observations.pluck(:id)).
             exclude_non_primary
    assert_includes(result, @obs1)
    assert_not_includes(result, @obs2)
    assert_not_includes(result, @obs3)
  end

  # == Phase 5: Thumbnail Tests ==

  def test_reassign_thumbnails_from_departing_observation
    occ = create_occurrence(@obs1, @obs2)
    img = images(:turned_over_image)
    @obs1.images << img
    # Set obs2's thumbnail to obs1's image
    @obs2.update_column(:thumb_image_id, img.id)

    occ.reassign_thumbnails_from(@obs1)
    @obs2.reload

    # obs2's thumbnail should have been reassigned
    assert_not_equal(img.id, @obs2.thumb_image_id)
  end

  def test_reset_cross_observation_thumbnails
    occ = create_occurrence(@obs1, @obs2)
    img = images(:turned_over_image)
    @obs1.images << img
    # Set obs2's thumbnail to obs1's image (cross-observation)
    @obs2.update_column(:thumb_image_id, img.id)

    occ.reset_cross_observation_thumbnails
    @obs2.reload

    # obs2's thumbnail should have been reset to its own image
    assert_not_equal(img.id, @obs2.thumb_image_id)
    if @obs2.images.any?
      assert_includes(@obs2.image_ids, @obs2.thumb_image_id)
    else
      assert_nil(@obs2.thumb_image_id)
    end
  end

  def test_reset_cross_observation_thumbnails_keeps_own
    occ = create_occurrence(@obs1, @obs2)
    img = images(:turned_over_image)
    @obs2.images << img
    @obs2.update_column(:thumb_image_id, img.id)

    occ.reset_cross_observation_thumbnails
    @obs2.reload

    # obs2's thumbnail is its own image, should remain
    assert_equal(img.id, @obs2.thumb_image_id)
  end

  def test_reassign_thumbnails_noop_when_no_shared_thumbnails
    occ = create_occurrence(@obs1, @obs2)
    img1 = images(:turned_over_image)
    img2 = images(:in_situ_image)
    @obs1.images << img1
    @obs2.images << img2
    @obs2.update_column(:thumb_image_id, img2.id)

    occ.reassign_thumbnails_from(@obs1)
    @obs2.reload

    assert_equal(img2.id, @obs2.thumb_image_id)
  end

  def test_exclude_non_primary_scope_includes_obs_without_occurrence
    obs_no_occ = observations(:strobilurus_diminutivus_obs)
    result = Observation.where(id: obs_no_occ.id).exclude_non_primary
    assert_includes(result, obs_no_occ)
  end

  # == Phase 6: Shared Consensus Tests ==

  def test_shared_consensus_across_occurrence
    create_occurrence(@obs1, @obs2)
    # Propose a name on obs1 and vote
    name = names(:agaricus_campestris)
    naming = Naming.create!(observation: @obs1, name: name, user: rolf)
    consensus = Observation::NamingConsensus.new(@obs1)
    consensus.change_vote(naming, Vote::MAXIMUM_VOTE, rolf)

    # obs2 should now share the consensus
    @obs2.reload
    assert_equal(name.id, @obs2.name_id,
                 "Sibling should share consensus name")
  end

  def test_consensus_reverts_on_removal_from_occurrence
    create_occurrence(@obs1, @obs2)
    name = names(:agaricus_campestris)
    naming = Naming.create!(observation: @obs1, name: name, user: rolf)
    consensus = Observation::NamingConsensus.new(@obs1)
    consensus.change_vote(naming, Vote::MAXIMUM_VOTE, rolf)

    # Both should share the occurrence consensus
    @obs2.reload
    shared_name_id = @obs2.name_id
    assert_equal(name.id, shared_name_id)

    # Remove obs2 from occurrence and recalculate standalone
    @obs2.update!(occurrence: nil)
    Observation::NamingConsensus.new(@obs2).calc_consensus
    @obs2.reload

    # obs2 should revert to its own local consensus (not the shared one)
    assert_not_equal(name.id, @obs2.name_id,
                     "Removed obs should not keep shared consensus")
  end

  def test_recalculate_consensus_on_occurrence
    occ = create_occurrence(@obs1, @obs2)
    name = names(:agaricus_campestris)
    Naming.create!(observation: @obs2, name: name, user: rolf).tap do |n|
      Vote.create!(naming: n, observation: @obs2, user: rolf,
                   value: Vote::MAXIMUM_VOTE, favorite: true)
    end

    occ.recalculate_consensus!
    @obs1.reload

    assert_equal(name.id, @obs1.name_id,
                 "Primary should get sibling's consensus")
  end

  def test_namings_panel_shows_occurrence_namings
    create_occurrence(@obs1, @obs2)
    name = names(:agaricus_campestris)
    naming = Naming.create!(observation: @obs2, name: name, user: rolf)

    consensus = Observation::NamingConsensus.new(@obs1)
    assert_includes(consensus.namings.map(&:id), naming.id,
                    "Consensus should include sibling's naming")
  end

  # -- destroy_if_incomplete! preserves occurrence with field_slip --

  def test_destroy_if_incomplete_preserves_with_field_slip
    fs = field_slips(:field_slip_no_obs)
    occ = create_occurrence(@obs1, @obs2)
    occ.update!(field_slip: fs)
    @obs2.update!(occurrence: nil)

    occ.destroy_if_incomplete!
    assert(Occurrence.exists?(occ.id),
           "Occurrence with field_slip should survive even with < 2 obs")
  end

  # -- recalculate_consensus! with no observations --

  def test_recalculate_consensus_noop_with_empty_occurrence
    occ = create_occurrence(@obs1, @obs2)
    @obs1.update!(occurrence: nil)
    @obs2.update!(occurrence: nil)
    occ.reload

    # Should not raise
    occ.recalculate_consensus!
  end

  # -- reassign_thumbnails_from departing obs with no images --

  def test_reassign_thumbnails_from_noop_when_departing_has_no_images
    occ = create_occurrence(@obs1, @obs2)
    # obs1 has no images, so nothing should change
    occ.reassign_thumbnails_from(@obs1)
    # No error raised means success
  end

  # -- FieldSlip#find_primary_observation --

  def test_field_slip_find_primary_observation
    fs = field_slips(:field_slip_no_obs)
    occ = create_occurrence(@obs1, @obs2)
    occ.update!(field_slip: fs)

    result = fs.find_primary_observation
    assert_equal(@obs1, result,
                 "Should return the primary observation")
  end

  def test_field_slip_find_primary_observation_without_occurrence
    fs = field_slips(:field_slip_no_obs)
    result = fs.find_primary_observation
    assert_nil(result,
               "Should return nil when no occurrence exists")
  end

  # == Phase 10: Logging and Notifications ==

  def test_create_manual_logs_observations
    User.current = rolf
    all_obs = [@obs1, @obs2]
    occ = Occurrence.create_manual(@obs1, all_obs, rolf)

    all_obs.each do |obs|
      obs.reload
      assert(obs.rss_log, "Obs #{obs.id} should have an rss_log")
      assert_match(/log_occurrence_added/, obs.rss_log.notes,
                   "Obs #{obs.id} rss_log should mention occurrence added")
    end
    occ.destroy!
  end

  def test_create_manual_notifies_other_owner
    User.current = rolf
    # obs3 is owned by mary, not rolf
    all_obs = [@obs1, @obs3]
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      Occurrence.create_manual(@obs1, all_obs, rolf)
    end
  end

  def test_log_observation_removed
    User.current = rolf
    create_occurrence(@obs1, @obs2, @obs3)
    Occurrence.log_observation_removed(@obs3)
    @obs3.reload
    assert_match(/log_occurrence_removed/, @obs3.rss_log.notes,
                 "Removed obs should have removal logged")
  end

  # == Coverage: dissolve! ==

  def test_dissolve_with_field_slip_keeps_occurrence
    User.current = rolf
    fs = field_slips(:field_slip_no_obs)
    occ = create_occurrence(@obs1, @obs2, @obs3)
    occ.update!(field_slip: fs)

    occ.dissolve!
    occ.reload

    assert(occ.persisted?,
           "Occurrence with field_slip should survive dissolve")
    assert_equal(1, occ.observations.count,
                 "Only primary should remain")
    assert_equal(@obs1, occ.primary_observation)
    assert_nil(@obs2.reload.occurrence_id)
    assert_nil(@obs3.reload.occurrence_id)
  end

  def test_dissolve_without_field_slip_destroys
    User.current = rolf
    occ = create_occurrence(@obs1, @obs2, @obs3)

    occ.dissolve!

    assert(occ.destroyed?,
           "Occurrence without field_slip should be destroyed")
    assert_nil(@obs1.reload.occurrence_id)
    assert_nil(@obs2.reload.occurrence_id)
    assert_nil(@obs3.reload.occurrence_id)
  end

  def test_dissolve_logs_removed_observations
    User.current = rolf
    occ = create_occurrence(@obs1, @obs2)

    occ.dissolve!

    [@obs1, @obs2].each do |obs|
      obs.reload
      assert(obs.rss_log, "Obs #{obs.id} should have rss_log")
      assert_match(/log_occurrence_removed/,
                   obs.rss_log.notes.to_s)
    end
  end

  def test_dissolve_with_field_slip_logs_only_non_primary
    User.current = rolf
    fs = field_slips(:field_slip_no_obs)
    occ = create_occurrence(@obs1, @obs2)
    occ.update!(field_slip: fs)
    clear_log(@obs1)

    occ.dissolve!

    @obs2.reload
    assert_match(/log_occurrence_removed/,
                 @obs2.rss_log.notes.to_s)
    # Primary stays in occurrence, should not get "removed" log
    @obs1.reload
    notes = @obs1.rss_log&.notes.to_s
    assert_no_match(/log_occurrence_removed/, notes)
  end

  # == Coverage: refresh_has_specimen_cache ==

  def test_refresh_has_specimen_cache_dry_run
    User.current = rolf
    occ = create_occurrence(@obs1, @obs2)
    @obs1.update!(specimen: true)
    # Force incorrect cached value
    occ.update_column(:has_specimen, false)

    msgs = Occurrence.refresh_has_specimen_cache(dry_run: true)

    assert(msgs.any? { |m| m.include?("Occurrence ##{occ.id}") },
           "Should report mismatch")
    occ.reload
    assert_not(occ.has_specimen,
               "Dry run should not change the value")
  end

  def test_refresh_has_specimen_cache_fixes_mismatch
    User.current = rolf
    occ = create_occurrence(@obs1, @obs2)
    @obs1.update!(specimen: true)
    occ.update_column(:has_specimen, false)

    msgs = Occurrence.refresh_has_specimen_cache(dry_run: false)

    assert(msgs.any?, "Should report corrections")
    occ.reload
    assert(occ.has_specimen, "Should fix cached value")
  end

  def test_refresh_has_specimen_cache_no_change_needed
    User.current = rolf
    occ = create_occurrence(@obs1, @obs2)
    @obs1.update!(specimen: false)
    @obs2.update!(specimen: false)
    occ.update_column(:has_specimen, false)

    msgs = Occurrence.refresh_has_specimen_cache(dry_run: false)

    assert_not(
      msgs.any? { |m| m.include?("Occurrence ##{occ.id}") },
      "Should not report when already correct"
    )
  end

  # == Coverage: check_multiple_occurrences! ==

  def test_check_multiple_occurrences_passes_with_one
    User.current = rolf
    occ = create_occurrence(@obs1, @obs2)
    # Should not raise
    Occurrence.check_multiple_occurrences!([occ])
  end

  def test_check_multiple_occurrences_passes_with_empty
    Occurrence.check_multiple_occurrences!([])
  end

  def test_check_multiple_occurrences_raises_with_two
    User.current = rolf
    occ1 = create_occurrence(@obs1, @obs2)
    occ2 = create_occurrence(@obs3, @obs4)

    err = assert_raises(ActiveRecord::RecordInvalid) do
      Occurrence.check_multiple_occurrences!([occ1, occ2])
    end
    assert_match(/multiple existing occurrences/, err.message)
  end

  # == Coverage: merge_into_manual ==

  def test_merge_into_manual_with_additional_obs
    User.current = rolf
    occ = create_occurrence(@obs1, @obs2)
    all = [@obs1, @obs2, @obs3, @obs4]
    result = Occurrence.create_manual(@obs3, all, rolf)

    assert_equal(occ.id, result.id,
                 "Should reuse existing occurrence")
    assert_equal(@obs3, result.primary_observation,
                 "Should set new primary")
    assert_equal(4, result.observations.count)
    assert_includes(result.observations, @obs3)
    assert_includes(result.observations, @obs4)
  end

  def test_merge_into_manual_two_existing_occurrences
    User.current = rolf
    occ1 = create_occurrence(@obs1, @obs2)
    occ2 = create_occurrence(@obs3, @obs4)
    all = [@obs1, @obs2, @obs3, @obs4]

    result = Occurrence.create_manual(@obs1, all, rolf)

    assert_equal(occ1.id, result.id)
    assert_not(Occurrence.exists?(occ2.id),
               "Absorbed occurrence should be destroyed")
    assert_equal(4, result.observations.count)
  end

  # ================================================================
  # Logging and notifications (from occurrence_logging_test)
  # ================================================================

  def test_create_new_no_existing_occurrences
    occ = Occurrence.create_manual(@obs1, [@obs1, @obs2], rolf)
    assert_log_entry(@obs1, "log_occurrence_added")
    assert_log_entry(@obs2, "log_occurrence_added")
    assert_activity_updated(@obs1)
    occ.destroy!
  end

  def test_create_new_notifies_other_owner
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      Occurrence.create_manual(@obs1, [@obs1, @obs3], rolf)
    end
  end

  def test_create_new_added_obs_has_occurrence
    existing_occ = create_occurrence(@obs3, @obs4)
    clear_logs(@obs1, @obs3, @obs4)
    occ = Occurrence.create_manual(@obs1, [@obs1, @obs3], rolf)
    assert_log_entry(@obs1, "log_occurrence_added")
    assert_log_entry(@obs3, "log_occurrence_updated")
    assert_activity_updated(occ.reload.primary_observation)
    assert_equal(existing_occ.id, occ.id)
  end

  def test_create_new_source_has_field_slip_occurrence
    slip = field_slips(:field_slip_one)
    fs_occ = Occurrence.create!(
      user: rolf, primary_observation: @obs1, field_slip: slip
    )
    @obs1.update!(occurrence: fs_occ)
    clear_logs(@obs1)
    occ = Occurrence.create_manual(@obs1, [@obs1, @obs2], rolf)
    assert_equal(fs_occ.id, occ.id)
    assert_log_entry(@obs2, "log_occurrence_added")
    assert_activity_updated(occ.reload.primary_observation)
  end

  def test_api_post_no_existing_occurrences
    occ = Occurrence.create_manual(@obs1, [@obs1, @obs2], rolf)
    assert_log_entry(@obs1, "log_occurrence_added")
    assert_log_entry(@obs2, "log_occurrence_added")
    assert_activity_updated(@obs1)
    occ.destroy!
  end

  def test_api_post_multiple_existing_occurrences_fails
    create_occurrence(@obs1, @obs2)
    create_occurrence(@obs3, @obs4)
    selected = [@obs1, @obs3]
    existing = selected.filter_map(&:occurrence).uniq
    assert_raises(ActiveRecord::RecordInvalid) do
      Occurrence.check_multiple_occurrences!(existing)
    end
  end

  def test_edit_add_no_existing_occurrence
    occ = create_occurrence(@obs1, @obs2)
    clear_logs(@obs1, @obs2)
    @obs3.update!(occurrence: occ)
    Occurrence.log_observation_added([@obs3])
    assert_log_entry(@obs3, "log_occurrence_added")
    assert_log_entry(@obs1, "log_occurrence_updated")
    assert_activity_updated(@obs1)
  end

  def test_edit_add_merge
    occ = create_occurrence(@obs1, @obs2)
    create_occurrence(@obs3, @obs4)
    clear_logs(@obs1, @obs2, @obs3, @obs4)
    Occurrence.merge!(occ, @obs3.reload.occurrence)
    assert_log_entry(@obs3, "log_occurrence_added")
    assert_log_entry(@obs4, "log_occurrence_added")
    assert_activity_updated(@obs1)
  end

  def test_edit_remove_occurrence_survives
    occ = create_occurrence(@obs1, @obs2, @obs3)
    clear_logs(@obs1, @obs2, @obs3)
    occ.reassign_thumbnails_from(@obs3)
    @obs3.update!(occurrence: nil)
    Occurrence.log_observation_removed(@obs3, occ)
    assert_log_entry(@obs3, "log_occurrence_removed")
    assert_log_entry(@obs1, "log_occurrence_updated")
    assert_activity_updated(@obs1)
  end

  def test_edit_remove_occurrence_destroyed
    occ = create_occurrence(@obs1, @obs2)
    clear_logs(@obs1, @obs2)
    occ.reassign_thumbnails_from(@obs2)
    @obs2.update!(occurrence: nil)
    Occurrence.log_observation_removed(@obs2, occ)
    occ.reload.destroy_if_incomplete!
    assert_log_entry(@obs2, "log_occurrence_removed")
  end

  def test_destroy_via_show_page
    occ = create_occurrence(@obs1, @obs2, @obs3)
    clear_logs(@obs1, @obs2, @obs3)
    detached = occ.observations.to_a
    occ.reset_cross_observation_thumbnails
    detached.each { |obs| obs.update!(occurrence: nil) }
    occ.reload.destroy!
    detached.each { |obs| Occurrence.log_observation_removed(obs) }
    assert_log_entry(@obs1, "log_occurrence_removed")
    assert_log_entry(@obs2, "log_occurrence_removed")
    assert_log_entry(@obs3, "log_occurrence_removed")
  end

  def test_destroy_via_api
    occ = create_occurrence(@obs1, @obs2)
    clear_logs(@obs1, @obs2)
    detached = occ.observations.to_a
    occ.reset_cross_observation_thumbnails
    occ.observations.update_all(occurrence_id: nil)
    occ.destroy!
    detached.each { |obs| Occurrence.log_observation_removed(obs) }
    assert_log_entry(@obs1, "log_occurrence_removed")
    assert_log_entry(@obs2, "log_occurrence_removed")
  end

  def test_change_primary_logging
    occ = create_occurrence(@obs1, @obs2)
    clear_logs(@obs1, @obs2)
    occ.update!(primary_observation: @obs2)
    Occurrence.touch_primary(occ)
    assert_log_entry(@obs2, "log_occurrence_updated")
    assert_activity_updated(@obs2)
  end

  def test_log_field_slip_added
    fs = field_slips(:field_slip_one)
    occ = create_occurrence(@obs1, @obs2)
    occ.update!(field_slip: fs)
    clear_logs(@obs1, @obs2)
    Occurrence.log_field_slip_added([@obs2])
    @obs2.reload
    assert_match(/log_field_slip_added/,
                 @obs2.rss_log.notes.to_s)
  end

  def test_log_field_slip_added_touches_primary
    fs = field_slips(:field_slip_one)
    occ = create_occurrence(@obs1, @obs2)
    occ.update!(field_slip: fs)
    clear_logs(@obs1, @obs2)
    Occurrence.log_field_slip_added([@obs2])
    @obs1.reload
    assert_match(/log_field_slip_updated/,
                 @obs1.rss_log.notes.to_s)
  end

  def test_log_field_slip_removed
    fs = field_slips(:field_slip_one)
    occ = create_occurrence(@obs1, @obs2, @obs3)
    occ.update!(field_slip: fs)
    clear_logs(@obs1, @obs2, @obs3)
    @obs3.update!(occurrence: nil)
    Occurrence.log_field_slip_removed(@obs3, occ)
    @obs3.reload
    assert_match(/log_field_slip_removed/,
                 @obs3.rss_log.notes.to_s)
  end

  def test_log_field_slip_removed_touches_primary
    fs = field_slips(:field_slip_one)
    occ = create_occurrence(@obs1, @obs2, @obs3)
    occ.update!(field_slip: fs)
    clear_logs(@obs1, @obs2, @obs3)
    @obs3.update!(occurrence: nil)
    Occurrence.log_field_slip_removed(@obs3, occ)
    @obs1.reload
    assert_match(/log_field_slip_updated/,
                 @obs1.rss_log.notes.to_s)
  end

  def test_touch_primary_with_name_param
    occ = create_occurrence(@obs1, @obs2)
    clear_logs(@obs1)
    Occurrence.touch_primary(
      occ, tag: :log_field_slip_updated, name: "FS-CODE"
    )
    @obs1.reload
    assert_match(/log_field_slip_updated/,
                 @obs1.rss_log.notes.to_s)
  end

  def test_touch_primary_excludes_listed_obs
    occ = create_occurrence(@obs1, @obs2)
    clear_logs(@obs1)
    Occurrence.touch_primary(occ, exclude: [@obs1])
    @obs1.reload
    assert_no_match(/log_occurrence_updated/,
                    @obs1.rss_log&.notes.to_s)
  end

  def test_touch_primary_nil_occ
    Occurrence.touch_primary(nil)
  end

  def test_field_slip_removed_without_occ_arg
    fs = field_slips(:field_slip_one)
    occ = create_occurrence(@obs1, @obs2)
    occ.update!(field_slip: fs)
    clear_logs(@obs1, @obs2)
    Occurrence.log_field_slip_removed(@obs2)
    @obs2.reload
    assert_match(/log_field_slip_removed/,
                 @obs2.rss_log.notes.to_s)
  end

  def test_notify_observation_owner_sends_email
    create_occurrence(@obs1, @obs3)
    clear_logs(@obs1, @obs3)
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      Occurrence.log_field_slip_added([@obs3])
    end
  end

  # ================================================================
  # Project membership gaps (from occurrence_project_gaps_test)
  # ================================================================

  def test_no_gaps_when_no_projects
    occ = create_occurrence(@obs1, @obs2)
    assert_equal({}, occ.project_membership_gaps)
  end

  def test_detects_primary_missing_from_project
    occ = create_occurrence(@obs1, @obs3)
    gaps = occ.project_membership_gaps
    assert(gaps[:projects]&.any?)
    assert(gaps[:primary_missing]&.any?)
  end

  def test_detects_non_primary_gaps
    project = projects(:bolete_project)
    ProjectObservation.create!(
      project: project, observation: @obs1
    )
    occ = create_occurrence(@obs1, @obs2)
    gaps = occ.project_membership_gaps
    assert(gaps[:has_non_primary_gaps])
  end

  def test_no_gaps_when_all_in_same_projects
    project = projects(:bolete_project)
    ProjectObservation.create!(
      project: project, observation: @obs1
    )
    ProjectObservation.create!(
      project: project, observation: @obs2
    )
    occ = create_occurrence(@obs1, @obs2)
    assert_equal({}, occ.project_membership_gaps)
  end

  def test_add_primary_to_collections
    project = projects(:bolete_project)
    occ = create_occurrence(@obs1, @obs3)
    occ.add_primary_to_collections(projects: [project])
    assert_includes(@obs1.reload.projects, project)
  end

  def test_add_all_to_collections
    project = projects(:bolete_project)
    occ = create_occurrence(@obs1, @obs2, @obs3)
    occ.add_all_to_collections(projects: [project])
    assert_includes(@obs1.reload.projects, project)
    assert_includes(@obs2.reload.projects, project)
    assert_includes(@obs3.reload.projects, project)
  end

  def test_add_primary_to_species_list
    spl = species_lists(:first_species_list)
    occ = create_occurrence(@obs1, @obs2)
    occ.add_primary_to_collections(species_lists: [spl])
    assert_includes(@obs1.reload.species_lists, spl)
  end

  def test_add_primary_to_projects_and_species_lists
    project = projects(:bolete_project)
    spl = species_lists(:first_species_list)
    occ = create_occurrence(@obs1, @obs2)
    occ.add_primary_to_collections(
      projects: [project], species_lists: [spl]
    )
    assert_includes(@obs1.reload.projects, project)
    assert_includes(@obs1.reload.species_lists, spl)
  end

  def test_add_primary_idempotent
    project = projects(:bolete_project)
    occ = create_occurrence(@obs1, @obs2)
    ProjectObservation.find_or_create_by!(
      project: project, observation: @obs1
    )
    occ.add_primary_to_collections(projects: [project])
    assert_equal(
      1,
      ProjectObservation.where(
        project: project, observation: @obs1
      ).count
    )
  end

  def test_add_all_to_species_list
    spl = species_lists(:first_species_list)
    occ = create_occurrence(@obs1, @obs2)
    occ.add_all_to_collections(species_lists: [spl])
    assert_includes(@obs1.reload.species_lists, spl)
    assert_includes(@obs2.reload.species_lists, spl)
  end

  def test_add_all_to_projects_and_species_lists
    project = projects(:bolete_project)
    spl = species_lists(:first_species_list)
    occ = create_occurrence(@obs1, @obs2, @obs3)
    occ.add_all_to_collections(
      projects: [project], species_lists: [spl]
    )
    [@obs1, @obs2, @obs3].each do |obs|
      assert_includes(obs.reload.projects, project)
      assert_includes(obs.reload.species_lists, spl)
    end
  end

  def test_project_gaps_with_mixed_membership
    project = projects(:bolete_project)
    occ = create_occurrence(@obs1, @obs3)
    gaps = occ.project_membership_gaps
    assert(gaps[:projects]&.include?(project))
    assert(gaps[:primary_missing]&.include?(project))
  end

  def test_any_obs_missing_detects_gap
    project = projects(:bolete_project)
    ProjectObservation.find_or_create_by!(
      project: project, observation: @obs1
    )
    occ = create_occurrence(@obs1, @obs2)
    gaps = occ.project_membership_gaps
    assert(gaps[:has_non_primary_gaps])
  end

  def test_no_non_primary_gaps_when_all_in_project
    project = projects(:bolete_project)
    ProjectObservation.find_or_create_by!(
      project: project, observation: @obs1
    )
    ProjectObservation.find_or_create_by!(
      project: project, observation: @obs2
    )
    occ = create_occurrence(@obs1, @obs2)
    gaps = occ.project_membership_gaps
    assert_equal({}, gaps)
  end

  # == Coverage: observation_count_within_limits (289-290) ==

  def test_observation_count_within_limits_validation
    User.current = rolf
    occ = create_occurrence(@obs1, @obs2)
    # Attach more observations to exceed limit
    extras = Observation.where.not(
      id: [@obs1.id, @obs2.id]
    ).limit(Occurrence::MAX_OBSERVATIONS).to_a
    extras.each { |obs| obs.update_columns(occurrence_id: occ.id) }
    occ.reload
    assert(occ.observations.count > Occurrence::MAX_OBSERVATIONS)
    assert_not(occ.valid?(:update),
               "Should be invalid with too many observations")
    assert(occ.errors[:observations].any?)
  end

  # == Coverage: dissolve_transaction field_slip branch ==

  def test_dissolve_field_slip_reloads_and_keeps_occ
    User.current = rolf
    fs = field_slips(:field_slip_no_obs)
    occ = create_occurrence(@obs1, @obs2, @obs3)
    occ.update!(field_slip: fs)

    occ.dissolve!
    occ.reload

    # With field slip: occurrence survives, only primary
    assert(occ.persisted?)
    assert_equal(1, occ.observations.count)
    assert_equal(@obs1.id, occ.primary_observation_id)
  end

  # == Coverage: dissolve_log_and_recalculate (306-310) ==

  def test_dissolve_recalculates_consensus_for_detached
    User.current = rolf
    # Create occurrence first, then add a naming
    occ = create_occurrence(@obs1, @obs2)
    name = names(:agaricus_campestris)
    naming = Naming.create!(
      observation: @obs1, name: name, user: rolf
    )
    consensus = Observation::NamingConsensus.new(@obs1)
    consensus.change_vote(naming, Vote::MAXIMUM_VOTE, rolf)

    # obs2 should have shared consensus
    @obs2.reload
    assert_equal(name.id, @obs2.name_id)

    occ.dissolve!

    # dissolve_log_and_recalculate should have run
    # calc_consensus on each detached obs
    @obs2.reload
    # obs2 has no namings of its own for agaricus, so
    # it should revert to its original name
    assert_not_equal(name.id, @obs2.name_id,
                     "Detached obs should revert consensus")
  end

  def test_dissolve_without_field_slip_logs_all
    User.current = rolf
    occ = create_occurrence(@obs1, @obs2, @obs3)
    clear_logs(@obs1, @obs2, @obs3)

    occ.dissolve!

    # All observations (including primary) should be logged
    [@obs1, @obs2, @obs3].each do |obs|
      obs.reload
      assert(obs.rss_log,
             "Obs #{obs.id} should have rss_log")
      assert_match(
        /log_occurrence_removed/,
        obs.rss_log.notes.to_s,
        "Obs #{obs.id} should have removal logged"
      )
    end
  end

  private

  def create_occurrence(primary_obs, *other_obs)
    occ = Occurrence.create!(
      user: rolf,
      primary_observation: primary_obs
    )
    primary_obs.update!(occurrence: occ)
    other_obs.each { |obs| obs.update!(occurrence: occ) }
    occ
  end

  def clear_log(obs)
    return unless obs.rss_log

    lines = obs.rss_log.notes.to_s.split("\n")
    lines.reject! { |l| l.include?("log_occurrence") }
    obs.rss_log.update_columns(
      notes: lines.join("\n"), updated_at: 1.day.ago
    )
    obs.update_columns(log_updated_at: 1.day.ago)
  end

  def clear_logs(*obs_list)
    obs_list.each do |obs|
      next unless obs.rss_log

      lines = obs.rss_log.notes.to_s.split("\n")
      lines.reject! do |l|
        l.include?("log_occurrence") ||
          l.include?("log_field_slip")
      end
      obs.rss_log.update_columns(
        notes: lines.join("\n"), updated_at: 1.day.ago
      )
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
           "Obs #{obs.id} log_updated_at should be recent")
  end
end

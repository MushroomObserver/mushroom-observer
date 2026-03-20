# frozen_string_literal: true

require("test_helper")

class OccurrenceTest < UnitTestCase
  def setup
    @obs1 = observations(:minimal_unknown_obs)
    @obs2 = observations(:coprinus_comatus_obs)
    @obs3 = observations(:detailed_unknown_obs)
    # Clear occurrence from field slip fixture
    @obs1.update_column(:occurrence_id, nil)
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

  # -- find_or_create_for_field_slip tests --

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

  def test_occurrence_substitutions_returns_non_primary_mapping
    occ = create_occurrence(@obs1, @obs2, @obs3)
    ids = [@obs1.id, @obs2.id, @obs3.id]
    subs = Observation.occurrence_substitutions(ids)

    # obs1 is primary, so it should NOT appear in the substitution map
    assert_not_includes(subs.keys, @obs1.id)
    # obs2 and obs3 are non-primary, so they should map to obs1
    assert_equal(occ.primary_observation_id, subs[@obs2.id])
    assert_equal(occ.primary_observation_id, subs[@obs3.id])
  end

  def test_occurrence_substitutions_ignores_obs_without_occurrence
    ids = [@obs1.id, @obs2.id]
    subs = Observation.occurrence_substitutions(ids)
    assert_empty(subs)
  end

  def test_occurrence_substitutions_empty_input
    assert_empty(Observation.occurrence_substitutions([]))
  end

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
    occ = create_occurrence(@obs1, @obs2)
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
    occ = create_occurrence(@obs1, @obs2)
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
    occ = create_occurrence(@obs1, @obs2)
    name = names(:agaricus_campestris)
    naming = Naming.create!(observation: @obs2, name: name, user: rolf)

    consensus = Observation::NamingConsensus.new(@obs1)
    assert_includes(consensus.namings.map(&:id), naming.id,
                    "Consensus should include sibling's naming")
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
end

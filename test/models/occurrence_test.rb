# frozen_string_literal: true

require("test_helper")

class OccurrenceTest < UnitTestCase
  def setup
    @obs1 = observations(:minimal_unknown_obs)
    @obs2 = observations(:coprinus_comatus_obs)
    @obs3 = observations(:detailed_unknown_obs)
  end

  def test_create_occurrence
    occ = create_occurrence(@obs1, @obs2)
    assert(occ.persisted?)
    assert_equal(2, occ.observations.count)
    assert_equal(@obs1, occ.default_observation)
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
      default_observation: obs_list.first
    )
    obs_list.each { |obs| obs.update!(occurrence: occ) }
    assert_not(occ.valid?)
    assert(occ.errors[:observations].any?)
  end

  def test_default_observation_must_belong
    occ = create_occurrence(@obs1, @obs2)
    occ.observations.load # preload so loaded? branch is covered
    occ.default_observation = @obs3
    assert_not(occ.valid?(:update))
    assert(occ.errors[:default_observation].any?)
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

  def test_find_or_create_for_field_slip_creates_new
    fs = field_slips(:field_slip_no_obs)
    @obs1.update!(field_slip: fs)
    @obs2.update!(field_slip: fs)

    occ = Occurrence.find_or_create_for_field_slip(fs, @obs2, rolf)
    assert(occ.persisted?)
    assert_equal(2, occ.observations.count)
    assert_includes(occ.observations, @obs1)
    assert_includes(occ.observations, @obs2)
    # Default should be oldest by created_at
    oldest = [@obs1, @obs2].min_by(&:created_at)
    assert_equal(oldest, occ.default_observation)
  end

  def test_find_or_create_for_field_slip_no_op_for_single_obs
    fs = field_slips(:field_slip_no_obs)
    @obs1.update!(field_slip: fs)

    result = Occurrence.find_or_create_for_field_slip(fs, @obs1, rolf)
    assert_nil(result)
    @obs1.reload
    assert_nil(@obs1.occurrence_id)
  end

  def test_find_or_create_for_field_slip_adds_to_existing
    fs = field_slips(:field_slip_no_obs)
    @obs1.update!(field_slip: fs)
    @obs2.update!(field_slip: fs)
    occ = create_occurrence(@obs1, @obs2)

    @obs3.update!(field_slip: fs)
    result = Occurrence.find_or_create_for_field_slip(fs, @obs3, rolf)
    assert_equal(occ, result)
    assert_equal(3, result.observations.count)
    # Default unchanged
    assert_equal(@obs1, result.default_observation)
  end

  def test_find_or_create_for_field_slip_merges_occurrences
    fs = field_slips(:field_slip_no_obs)
    @obs1.update!(field_slip: fs)
    @obs2.update!(field_slip: fs)
    occ_a = create_occurrence(@obs1, @obs2)

    obs4 = observations(:amateur_obs)
    obs5 = observations(:peltigera_obs)
    occ_b = create_occurrence(obs4, obs5)
    obs4.update!(field_slip: fs)

    result = Occurrence.find_or_create_for_field_slip(fs, obs4, rolf)
    assert_equal(occ_a.id, result.id)
    assert_equal(4, result.observations.count)
    assert(Occurrence.where(id: occ_b.id).none?,
           "Absorbed occurrence should be destroyed")
  end

  # -- create_manual tests --

  def test_create_manual
    selected = [@obs1, @obs2]
    occ = Occurrence.create_manual(@obs1, selected, rolf)
    assert(occ.persisted?)
    assert_equal(@obs1, occ.default_observation)
    assert_equal(2, occ.observations.count)
  end

  def test_create_manual_merges_existing
    occ_existing = create_occurrence(@obs2, @obs3)
    selected = [@obs1, @obs2, @obs3]
    result = Occurrence.create_manual(@obs1, selected, rolf)
    assert_equal(occ_existing.id, result.id)
    assert_equal(@obs1, result.default_observation)
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

  private

  def create_occurrence(default_obs, *other_obs)
    occ = Occurrence.create!(
      user: rolf,
      default_observation: default_obs
    )
    default_obs.update!(occurrence: occ)
    other_obs.each { |obs| obs.update!(occurrence: occ) }
    occ
  end
end

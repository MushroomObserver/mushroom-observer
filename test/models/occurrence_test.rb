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
    occ.default_observation = @obs3
    assert_not(occ.valid?)
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

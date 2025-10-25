# frozen_string_literal: true

require("test_helper")

class HerbariumRecords::RemoveObservationsControllerTest < FunctionalTestCase
  def setup_test_fixtures
    obs1 = observations(:agaricus_campestris_obs)
    obs2 = observations(:coprinus_comatus_obs)
    rec1 = obs1.herbarium_records.first
    rec2 = obs2.herbarium_records.first
    [obs1, obs2, rec1, rec2]
  end

  def test_fixtures_are_correct
    obs1, obs2, rec1, rec2 = setup_test_fixtures
    assert_true(obs1.herbarium_records.include?(rec1))
    assert_true(obs2.herbarium_records.include?(rec2))
  end

  # Make sure user must be logged in.
  def test_must_be_logged_in
    obs1, _obs2, rec1, _rec2 = setup_test_fixtures

    patch(:update, params: { herbarium_record_id: rec1.id,
                             observation_id: obs1.id })
    assert_true(obs1.reload.herbarium_records.include?(rec1))
  end

  # Make sure only owner obs can remove rec from it.
  def test_only_owner_can_remove
    obs1, _obs2, rec1, _rec2 = setup_test_fixtures

    login("mary")
    patch(:update,
          params: { herbarium_record_id: rec1.id, observation_id: obs1.id })
    assert_true(obs1.reload.herbarium_records.include?(rec1))
  end

  # Make sure badly-formed queries don't crash.
  def test_badly_formed_queries_dont_crash
    obs1, obs2, rec1, rec2 = setup_test_fixtures

    login("rolf")
    patch(:update, params: { herbarium_record_id: -1 })
    patch(:update, params: { herbarium_record_id: rec1.id })
    patch(:update,
          params: { herbarium_record_id: rec1.id, observation_id: "bogus" })
    patch(:update,
          params: { herbarium_record_id: rec1.id, observation_id: obs2.id })
    assert_true(obs1.reload.herbarium_records.include?(rec1))
    assert_true(obs2.reload.herbarium_records.include?(rec2))
  end

  def test_removing_destroys_only_when_appropriate
    obs1, obs2, rec1, rec2 = setup_test_fixtures

    login("rolf")
    # Removing rec from last obs destroys it.
    patch(:update,
          params: { herbarium_record_id: rec1.id, observation_id: obs1.id })
    assert_empty(obs1.reload.herbarium_records)
    assert_nil(HerbariumRecord.safe_find(rec1.id))

    # Removing rec from one of two obs does not destroy it.
    rec2.add_observation(obs1)
    assert_true(obs1.reload.herbarium_records.include?(rec2))
    assert_true(obs2.reload.herbarium_records.include?(rec2))
    patch(:update,
          params: { herbarium_record_id: rec2.id, observation_id: obs2.id })
    assert_true(obs1.reload.herbarium_records.include?(rec2))
    assert_false(obs2.reload.herbarium_records.include?(rec2))
    assert_not_nil(HerbariumRecord.safe_find(rec2.id))

    # Finally make sure admin has permission.
    make_admin("mary")
    patch(:update,
          params: { herbarium_record_id: rec2.id, observation_id: obs1.id })
    assert_empty(obs1.reload.herbarium_records)
    assert_nil(HerbariumRecord.safe_find(rec2.id))
  end

  def test_remove_observation_redirect
    obs   = observations(:detailed_unknown_obs)
    recs  = obs.herbarium_records
    @controller.find_or_create_query(:HerbariumRecord)
    login(obs.user.login)
    assert_operator(recs.length, :>, 1)

    # Prove that it keeps query param intact when returning to observation.
    patch(:update,
          params: { herbarium_record_id: recs[1].id, observation_id: obs.id })
    assert_redirected_to(observation_path(id: obs.id))
    assert_session_query_record_is_correct
  end

  def test_turbo_remove_herbarium_record_non_owner
    obs1, _obs2, rec1, _rec2 = setup_test_fixtures

    # non-owner cannot
    login("mary")
    params = { herbarium_record_id: rec1.id,
               observation_id: obs1.id }
    patch(:update, params: params,
                   format: :turbo_stream)
    assert_true(obs1.reload.herbarium_records.include?(rec1))
  end

  def test_turbo_remove_herbarium_record_owner
    obs1, _obs2, rec1, _rec2 = setup_test_fixtures

    # owner can
    login("rolf")
    params = { herbarium_record_id: rec1.id,
               observation_id: obs1.id }
    patch(:update, params: params,
                   format: :turbo_stream)
    assert_empty(obs1.reload.herbarium_records)
  end
end

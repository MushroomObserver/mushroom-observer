# frozen_string_literal: true

require "test_helper"

class HerbariumRecords::RemoveObservationsControllerTest < FunctionalTestCase
  def test_remove_observation
    obs1 = observations(:agaricus_campestris_obs)
    obs2 = observations(:coprinus_comatus_obs)
    rec1 = obs1.herbarium_records.first
    rec2 = obs2.herbarium_records.first
    assert_true(obs1.herbarium_records.include?(rec1))
    assert_true(obs2.herbarium_records.include?(rec2))

    # Make sure user must be logged in.
    patch(:update, params: { herbarium_record_id: rec1.id,
                             observation_id: obs1.id })
    assert_true(obs1.reload.herbarium_records.include?(rec1))

    # Make sure only owner obs can remove rec from it.
    login("mary")
    patch(:update,
          params: { herbarium_record_id: rec1.id, observation_id: obs1.id })
    assert_true(obs1.reload.herbarium_records.include?(rec1))

    # Make sure badly-formed queries don't crash.
    login("rolf")
    # patch(:update)
    patch(:update, params: { herbarium_record_id: -1 })
    patch(:update, params: { herbarium_record_id: rec1.id })
    patch(:update,
          params: { herbarium_record_id: rec1.id, observation_id: "bogus" })
    patch(:update,
          params: { herbarium_record_id: rec1.id, observation_id: obs2.id })
    assert_true(obs1.reload.herbarium_records.include?(rec1))
    assert_true(obs2.reload.herbarium_records.include?(rec2))

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
    query = Query.lookup_and_save(:HerbariumRecord, :all)
    q     = query.id.alphabetize
    login(obs.user.login)
    assert_operator(recs.length, :>, 1)

    # Prove that it keeps query param intact when returning to observation.
    patch(:update,
          params: { herbarium_record_id: recs[1].id, observation_id: obs.id,
                    q: q })
    assert_redirected_to(observation_path(id: obs.id, q: q))
  end
end

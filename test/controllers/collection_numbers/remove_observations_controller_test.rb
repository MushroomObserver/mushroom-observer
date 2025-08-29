# frozen_string_literal: true

require("test_helper")

class CollectionNumbers::RemoveObservationsControllerTest < FunctionalTestCase
  def setup_test_fixtures
    obs1 = observations(:agaricus_campestris_obs)
    obs2 = observations(:coprinus_comatus_obs)
    num1 = collection_numbers(:agaricus_campestris_coll_num)
    num2 = collection_numbers(:coprinus_comatus_coll_num)
    [obs1, obs2, num1, num2]
  end

  def test_fixtures_are_correct
    obs1, obs2, num1, num2 = setup_test_fixtures
    assert_obj_arrays_equal([num1], obs1.collection_numbers)
    assert_obj_arrays_equal([num2], obs2.collection_numbers)
  end

  # Make sure user must be logged in.
  def test_must_be_logged_in
    obs1, _obs2, num1, _num2 = setup_test_fixtures

    patch(:update, params: { collection_number_id: num1.id,
                             observation_id: obs1.id })
    assert_obj_arrays_equal([num1], obs1.reload.collection_numbers)
  end

  # Make sure only owner obs can remove num from it.
  def test_only_owner_can_remove
    obs1, _obs2, num1, _num2 = setup_test_fixtures

    login("mary") # owner is rolf
    patch(:update, params: { collection_number_id: num1.id,
                             observation_id: obs1.id })
    assert_obj_arrays_equal([num1], obs1.reload.collection_numbers)
  end

  # Make sure badly-formed queries don't crash.
  def test_badly_formed_queries_dont_crash
    obs1, obs2, num1, num2 = setup_test_fixtures

    login("rolf")
    patch(:update, params: { collection_number_id: -1 })
    patch(:update, params: { collection_number_id: num1.id })
    patch(:update, params: { collection_number_id: num1.id,
                             observation_id: "bogus" })
    # wrong observation for num1
    patch(:update, params: { collection_number_id: num1.id,
                             observation_id: obs2.id })
    assert_obj_arrays_equal([num1], obs1.reload.collection_numbers)
    assert_obj_arrays_equal([num2], obs2.reload.collection_numbers)
  end

  def test_removing_destroys_only_when_appropriate
    obs1, obs2, num1, num2 = setup_test_fixtures

    login("rolf")
    # Removing num from last obs destroys it.
    patch(:update, params: { collection_number_id: num1.id,
                             observation_id: obs1.id })
    assert_empty(obs1.reload.collection_numbers)
    assert_nil(CollectionNumber.safe_find(num1.id))

    # Removing num from one of two obs does not destroy it.
    num2.add_observation(obs1)
    assert_obj_arrays_equal([num2], obs1.reload.collection_numbers)
    assert_obj_arrays_equal([num2], obs2.reload.collection_numbers)
    patch(:update, params: { collection_number_id: num2.id,
                             observation_id: obs2.id })
    assert_obj_arrays_equal([num2], obs1.reload.collection_numbers)
    assert_empty(obs2.reload.collection_numbers)
    assert_not_nil(CollectionNumber.safe_find(num2.id))

    # Finally make sure admin has permission.
    make_admin("mary")
    patch(:update, params: { collection_number_id: num2.id,
                             observation_id: obs1.id })
    assert_empty(obs1.reload.collection_numbers)
    assert_nil(CollectionNumber.safe_find(num2.id))
  end

  def test_remove_observation_redirect
    obs   = observations(:detailed_unknown_obs)
    nums  = obs.collection_numbers
    @controller.find_or_create_query(:CollectionNumber)

    login(obs.user.login)
    assert_operator(nums.length, :>, 1)

    # Prove that it keeps query param intact when returning to observation.
    patch(:update, params: { collection_number_id: nums[1].id,
                             observation_id: obs.id })
    assert_redirected_to(observation_path(id: obs.id))
    assert_session_query_record_is_correct
  end

  def test_turbo_remove_collection_number_non_owner
    obs1, _obs2, num1, _num2 = setup_test_fixtures

    # non-owner cannot
    login("mary")
    params = { collection_number_id: num1.id,
               observation_id: obs1.id }
    patch(:update, params: params,
                   format: :turbo_stream)
    assert_obj_arrays_equal([num1], obs1.reload.collection_numbers)
  end

  def test_turbo_remove_collection_number_owner
    obs1, _obs2, num1, _num2 = setup_test_fixtures

    # owner can
    login("rolf")
    params = { collection_number_id: num1.id,
               observation_id: obs1.id }
    patch(:update, params: params,
                   format: :turbo_stream)
    assert_empty(obs1.reload.collection_numbers)
  end
end

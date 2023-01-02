# frozen_string_literal: true

require "test_helper"

class CollectionNumbers::RemoveObservationsControllerTest < FunctionalTestCase
  def test_remove_observation
    obs1 = observations(:agaricus_campestris_obs)
    obs2 = observations(:coprinus_comatus_obs)
    num1 = collection_numbers(:agaricus_campestris_coll_num)
    num2 = collection_numbers(:coprinus_comatus_coll_num)
    assert_obj_arrays_equal([num1], obs1.collection_numbers)
    assert_obj_arrays_equal([num2], obs2.collection_numbers)

    # Make sure user must be logged in.
    patch(:update, params: { collection_number_id: num1.id,
                             observation_id: obs1.id })
    assert_obj_arrays_equal([num1], obs1.reload.collection_numbers)

    # Make sure only owner obs can remove num from it.
    login("mary")
    patch(:update, params: { collection_number_id: num1.id,
                             observation_id: obs1.id })
    assert_obj_arrays_equal([num1], obs1.reload.collection_numbers)

    # Make sure badly-formed queries don't crash.
    login("rolf")
    # patch(:update) not a valid route
    patch(:update, params: { collection_number_id: -1 })
    patch(:update, params: { collection_number_id: num1.id })
    patch(:update, params: { collection_number_id: num1.id,
                             observation_id: "bogus" })
    patch(:update, params: { collection_number_id: num1.id,
                             observation_id: obs2.id })
    assert_obj_arrays_equal([num1], obs1.reload.collection_numbers)
    assert_obj_arrays_equal([num2], obs2.reload.collection_numbers)

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
    query = Query.lookup_and_save(:CollectionNumber, :all)
    q     = query.id.alphabetize
    login(obs.user.login)
    assert_operator(nums.length, :>, 1)

    # Prove that it keeps query param intact when returning to observation.
    patch(:update, params: { collection_number_id: nums[1].id,
                             observation_id: obs.id, q: q })
    assert_redirected_to(observation_path(id: obs.id, q: q))
  end
end

# frozen_string_literal: true

require("test_helper")
require("api2_extensions")

class API2::CollectionNumbersTest < UnitTestCase
  include API2Extensions

  def test_basic_collection_number_get
    do_basic_get_test(CollectionNumber)
  end

  # ---------------------------------------
  #  :section: Collection Number Requests
  # ---------------------------------------

  def params_get(**)
    { method: :get, action: :collection_number }.merge(**)
  end

  def test_getting_collection_numbers_created_at
    nums = CollectionNumber.where(CollectionNumber[:created_at].year.eq(2006))
    assert_not_empty(nums)
    assert_api_pass(params_get(created_at: "2006"))
    assert_api_results(nums)
  end

  def test_getting_collection_numbers_updated_at
    nums = CollectionNumber.where(CollectionNumber[:updated_at].year.eq(2005))
    assert_not_empty(nums)
    assert_api_pass(params_get(updated_at: "2005"))
    assert_api_results(nums)
  end

  def test_getting_collection_numbers_user
    nums = CollectionNumber.where(user: mary)
    assert_not_empty(nums)
    assert_api_pass(params_get(user: "mary"))
    assert_api_results(nums)
  end

  def test_getting_collection_numbers_observation
    obs  = observations(:detailed_unknown_obs)
    nums = obs.collection_numbers
    assert_not_empty(nums)
    assert_api_pass(params_get(observation: obs.id))
    assert_api_results(nums)
  end

  def test_getting_collection_numbers_collector
    nums = CollectionNumber.where(name: "Mary Newbie")
    assert_not_empty(nums)
    assert_api_pass(params_get(collector: "Mary Newbie"))
    assert_api_results(nums)
  end

  def test_getting_collection_numbers_collector_has
    nums = CollectionNumber.where(CollectionNumber[:name].matches("%mary%"))
    assert_not_empty(nums)
    assert_api_pass(params_get(collector_has: "Mary"))
    assert_api_results(nums)
  end

  def test_getting_collection_numbers_number
    nums = CollectionNumber.where(number: "174")
    assert_not_empty(nums)
    assert_api_pass(params_get(number: "174"))
    assert_api_results(nums)
  end

  def test_getting_collection_numbers_number_has
    # nums = CollectionNumber.where("number LIKE '%17%'")
    nums = CollectionNumber.where(CollectionNumber[:number].matches("%17%"))
    assert_not_empty(nums)
    assert_api_pass(params_get(number_has: "17"))
    assert_api_results(nums)
  end

  def test_posting_collection_numbers
    rolfs_obs  = observations(:strobilurus_diminutivus_obs)
    marys_obs  = observations(:detailed_unknown_obs)
    @obs       = rolfs_obs
    @name      = "Someone Else"
    @number    = "13579a"
    @user      = rolf
    params = {
      method: :post,
      action: :collection_number,
      api_key: @api_key.key,
      observation: @obs.id,
      collector: @name,
      number: @number
    }
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.except(:observation))
    assert_api_fail(params.except(:number))
    assert_api_fail(params.merge(observation: marys_obs.id))
    assert_api_pass(params)
    assert_last_collection_number_correct

    collection_number_count = CollectionNumber.count
    rolfs_other_obs = observations(:stereum_hirsutum_1)
    assert_api_pass(params.merge(observation: rolfs_other_obs.id))
    assert_equal(collection_number_count, CollectionNumber.count)
    assert_obj_arrays_equal([rolfs_obs, rolfs_other_obs],
                            CollectionNumber.last.
                            observations.reorder(id: :asc), :sort)
  end

  def test_patching_collection_numbers
    rolfs_num = collection_numbers(:coprinus_comatus_coll_num)
    marys_num = collection_numbers(:minimal_unknown_coll_num)
    rolfs_rec = herbarium_records(:coprinus_comatus_rolf_spec)
    params = {
      method: :patch,
      action: :collection_number,
      api_key: @api_key.key,
      id: rolfs_num.id,
      set_collector: "New",
      set_number: "42"
    }
    assert_equal("Rolf Singer 1", rolfs_rec.accession_number)
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.merge(id: marys_num.id))
    assert_api_pass(params)
    assert_equal("New", rolfs_num.reload.name)
    assert_equal("42", rolfs_num.reload.number)
    assert_equal("New 42", rolfs_rec.reload.accession_number)

    old_obs   = rolfs_num.observations.first
    rolfs_obs = observations(:agaricus_campestris_obs)
    marys_obs = observations(:detailed_unknown_obs)
    params = {
      method: :patch,
      action: :collection_number,
      api_key: @api_key.key,
      id: rolfs_num.id
    }
    assert_api_fail(params.merge(add_observation: marys_obs.id))
    assert_api_pass(params.merge(add_observation: rolfs_obs.id))
    assert_obj_arrays_equal([old_obs, rolfs_obs], rolfs_num.reload.observations,
                            :sort)
    assert_api_pass(params.merge(remove_observation: old_obs.id))
    assert_obj_arrays_equal([rolfs_obs], rolfs_num.reload.observations)
    assert_api_pass(params.merge(remove_observation: rolfs_obs.id))
    assert_nil(CollectionNumber.safe_find(rolfs_num.id))
  end

  def test_patching_collection_numbers_merge
    num1 = collection_numbers(:coprinus_comatus_coll_num)
    num2 = collection_numbers(:agaricus_campestris_coll_num)
    obs1 = num1.observations.first
    obs2 = num2.observations.first
    params = {
      method: :patch,
      action: :collection_number,
      api_key: @api_key.key,
      id: num1.id,
      set_number: num2.number
    }
    assert_api_pass(params)
    assert_obj_arrays_equal(obs1.reload.collection_numbers,
                            obs2.reload.collection_numbers)
    assert_equal(1, obs1.collection_numbers.count)
  end

  def test_deleting_collection_numbers
    rolfs_num = collection_numbers(:coprinus_comatus_coll_num)
    marys_num = collection_numbers(:minimal_unknown_coll_num)
    params = {
      method: :delete,
      action: :collection_number,
      api_key: @api_key.key,
      id: rolfs_num.id
    }
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.merge(id: marys_num.id))
    assert_api_pass(params)
    assert_nil(CollectionNumber.safe_find(rolfs_num.id))
  end
end

# frozen_string_literal: true

require "test_helper"

class CollectionNumbersControllerTest < FunctionalTestCase
  def test_index
    get_with_dump(:index)
    assert_template(:index)
  end

  def test_observation_index_with_one_collection_number
    obs = observations(:minimal_unknown_obs)
    assert_equal(1, obs.collection_numbers.count)
    get_with_dump(:observation_index, id: obs.id)
    assert_template(:index)
    assert_no_flash
  end

  def test_observation_index_with_multiple_collection_numbers
    obs = observations(:detailed_unknown_obs)
    assert_operator(obs.collection_numbers.count, :>, 1)
    get_with_dump(:observation_index, id: obs.id)
    assert_template(:index)
    assert_no_flash
  end

  def test_observation_index_with_no_collection_numbers
    obs = observations(:strobilurus_diminutivus_obs)
    assert_empty(obs.collection_numbers)
    get_with_dump(:observation_index, id: obs.id)
    assert_template(:index)
    assert_flash_text(/no matching collection numbers found/i)
  end

  def test_collection_number_search
    numbers = CollectionNumber.where("name like '%singer%'")
    assert_operator(numbers.count, :>, 1)
    get(:collection_number_search, pattern: "Singer")
    assert_response(:success)
    assert_template(:index)
    # In results, expect 1 row per collection_number.
    assert_select("tr", numbers.count)
  end

  def test_collection_number_search_with_one_collection_number_index
    numbers = CollectionNumber.where("name like '%neighbor%'")
    assert_equal(1, numbers.count)
    get_with_dump(:collection_number_search, pattern: "neighbor")
    query_record = QueryRecord.last
    assert_redirected_to(action: :show,
                         id: numbers.first.id, q: query_record.id.alphabetize)
    assert_no_flash
  end

  def test_index_collection_number_with_query
    query = Query.lookup_and_save(:CollectionNumber, :all, users: rolf)
    assert_operator(query.num_results, :>, 1)
    get(:index_collection_number, q: query.record.id.alphabetize)
    assert_response(:success)
    assert_template(:index)
    # In results, expect 1 row per collection_number.
    assert_select("tr", query.num_results)
  end

  def test_show
    get(:show, id: "bogus")

    number = collection_numbers(:detailed_unknown_coll_num_two)
    get_with_dump(:show, id: number.id)
  end

  def test_show_next
    query = Query.lookup_and_save(:CollectionNumber, :all, users: rolf)
    assert_operator(query.num_results, :>, 1)
    number1 = query.results[0]
    number2 = query.results[1]
    q = query.record.id.alphabetize

    get(:show_next, id: number1.id, q: q)
    assert_redirected_to(action: :show, id: number2.id, q: q)
  end

  def test_show_prev
    query = Query.lookup_and_save(:CollectionNumber, :all, users: rolf)
    assert_operator(query.num_results, :>, 1)
    number1 = query.results[0]
    number2 = query.results[1]
    q = query.record.id.alphabetize

    get(:show_prev, id: number2.id, q: q)
    assert_redirected_to(action: :show, id: number1.id, q: q)
  end

  def test_new
    get(:new)
    get(:new, id: "bogus")

    obs = observations(:coprinus_comatus_obs)
    get(:new, id: obs.id)
    assert_response(:redirect)

    login("mary")
    get(:new, id: obs.id)
    assert_response(:redirect)

    login("rolf")
    get_with_dump(:new, id: obs.id)
    assert_response(:success)
    assert_template("new", partial: "shared/log_item")
    assert(assigns(:collection_number))

    make_admin("mary")
    get(:new, id: obs.id)
    assert_response(:success)
  end

  def test_new_redirect
    obs = observations(:coprinus_comatus_obs)
    query = Query.lookup_and_save(:CollectionNumber, :all)
    q = query.id.alphabetize
    params = {
      id: obs.id,
      collection_number: { name: "John Doe", number: "31415" },
      q: q
    }

    # Prove that query params are added to form action.
    login(obs.user.login)
    get(:new, params)
    assert_select("form:match('action', ?)", /\?.*q=#{q}/)
  end

  def test_create
    collection_number_count = CollectionNumber.count
    obs = observations(:strobilurus_diminutivus_obs)
    assert_false(obs.specimen)
    assert_empty(obs.collection_numbers)
    params = {
      name: "  Some  Person <spam>  ",
      number: "  71-1234-c <spam>   "
    }

    post(:create, id: obs.id, collection_number: params)
    assert_equal(collection_number_count, CollectionNumber.count)
    assert_redirected_to(controller: :account, action: :login)

    login("mary")
    post(:create, id: obs.id, collection_number: params)
    assert_equal(collection_number_count, CollectionNumber.count)
    assert_flash_text(/permission denied/i)

    login("rolf")
    post(:create, id: obs.id, collection_number: params.except(:name))
    assert_flash_text(/missing.*name/i)
    assert_equal(collection_number_count, CollectionNumber.count)
    post(:create, id: obs.id, collection_number: params.except(:number))
    assert_flash_text(/missing.*number/i)
    assert_equal(collection_number_count, CollectionNumber.count)
    post(:create, id: obs.id, collection_number: params)
    assert_equal(collection_number_count + 1, CollectionNumber.count)
    assert_no_flash
    assert_response(:redirect)

    number = CollectionNumber.last
    assert_in_delta(Time.zone.now, number.created_at, 1.minute)
    assert_in_delta(Time.zone.now, number.updated_at, 1.minute)
    assert_equal(rolf, number.user)
    assert_equal("Some Person", number.name)
    assert_equal("71-1234-c", number.number)
    assert_true(obs.reload.specimen)
    assert_includes(obs.collection_numbers, number)
  end

  def test_create_twice
    collection_number_count = CollectionNumber.count
    obs = observations(:strobilurus_diminutivus_obs)
    assert_empty(obs.collection_numbers)
    params = {
      name: "John Doe",
      number: "1234"
    }

    login("rolf")
    post(:create, id: obs.id, collection_number: params)
    assert_equal(collection_number_count + 1, CollectionNumber.count)
    assert_no_flash
    number = CollectionNumber.last
    assert_obj_list_equal([number], obs.reload.collection_numbers)

    post(:create, id: obs.id, collection_number: params)
    assert_equal(collection_number_count + 1, CollectionNumber.count)
    assert_flash_text(/shared/i)
    assert_obj_list_equal([number], obs.reload.collection_numbers)
  end

  def test_create_already_used
    collection_number_count = CollectionNumber.count
    obs1 = observations(:coprinus_comatus_obs)
    obs2 = observations(:detailed_unknown_obs)
    assert_equal(1, obs1.collection_numbers.count)
    assert_equal(2, obs2.collection_numbers.count)
    number = obs1.collection_numbers.first
    assert_equal(1, number.observations.count)
    params = {
      name: number.name,
      number: number.number
    }

    login("mary")
    post(:create, id: obs2.id, collection_number: params)
    assert_equal(collection_number_count, CollectionNumber.count)
    assert_flash_text(/shared/i)
    assert_equal(1, obs1.reload.collection_numbers.count)
    assert_equal(3, obs2.reload.collection_numbers.count)
    assert_equal(2, number.reload.observations.count)
    assert_includes(obs2.collection_numbers, number)
    assert_includes(number.observations, obs2)
  end

  def test_create_redirect
    obs = observations(:coprinus_comatus_obs)
    query = Query.lookup_and_save(:CollectionNumber, :all)
    q = query.id.alphabetize
    params = {
      id: obs.id,
      collection_number: { name: "John Doe", number: "31415" },
      q: q
    }

    # Prove that post keeps query params intact.
    login(obs.user.login)
    post(:create, params)
    assert_redirected_to(observation_path(obs.id, q: q))
  end

  def test_edit
    get(:edit, id: "bogus")

    number = collection_numbers(:coprinus_comatus_coll_num)
    get(:edit, id: number.id)
    assert_response(:redirect)

    login("mary")
    get(:edit, id: number.id)
    assert_response(:redirect)

    login("rolf")
    get_with_dump(:edit, id: number.id)
    assert_response(:success)
    assert_template("edit", partial: "shared/log_item")
    assert_objs_equal(number, assigns(:collection_number))

    make_admin("mary")
    get(:edit, id: number.id)
    assert_response(:success)
  end

  def test_edit_redirect
    obs   = observations(:detailed_unknown_obs)
    num   = obs.collection_numbers.first
    query = Query.lookup_and_save(:CollectionNumber, :all)
    q     = query.id.alphabetize
    login(obs.user.login)
    params = {
      id: num.id,
      collection_number: { name: num.name, number: num.number }
    }

    # Prove that edit passes "back" and query param through to form.
    get(:edit, params.merge(back: "foo", q: q))
    assert_select("form:match('action', ?)", /\?.*q=#{q}/)
    assert_select("form:match('action', ?)", /\?.*back=foo/)
  end

  def test_update
    obs = observations(:coprinus_comatus_obs)
    number = collection_numbers(:coprinus_comatus_coll_num)
    record1 = herbarium_records(:coprinus_comatus_rolf_spec)
    record2 = herbarium_records(:coprinus_comatus_nybg_spec)

    # Verify that the observation has an herbarium record which is using the
    # collection number.  When we change the collection number it should also
    # update the "accession number" in the herbarium record.  (But the one
    # at NYBG has already been accessioned, so it should not be changed.)
    assert_includes(obs.collection_numbers, number)
    assert_includes(obs.herbarium_records, record1)
    assert_includes(obs.herbarium_records, record2)
    assert_equal(number.format_name, record1.accession_number)
    assert_not_equal(number.format_name, record2.accession_number)
    old_nybg_accession = record2.accession_number

    params = {
      name: "  New   Name <spam>  ",
      number: "  69-abc <spam>  "
    }

    patch(:update, params: { id: number.id, collection_number: params })
    assert_redirected_to(controller: :account, action: :login)

    login("mary")
    patch(:update, params: { id: number.id, collection_number: params })
    assert_flash_text(/permission denied/i)

    login("rolf")
    patch(:update,
          params: { id: number.id, collection_number: params.merge(name: "") })
    assert_flash_text(/missing.*name/i)
    assert_not_equal("new number", number.reload.number)

    patch(:update,
          params: { id: number.id,
                    collection_number: params.merge(number: "") })
    assert_flash_text(/missing.*number/i)
    assert_not_equal("New Name", number.reload.name)

    patch(:update, params: { id: number.id, collection_number: params })
    assert_no_flash
    assert_response(:redirect)
    assert_equal("New Name", number.reload.name)
    assert_equal("69-abc", number.number)
    assert_in_delta(Time.zone.now, number.updated_at, 1.minute)
    assert_equal("New Name 69-abc", number.reload.format_name)
    assert_equal("New Name 69-abc", record1.reload.accession_number)
    assert_equal(old_nybg_accession, record2.reload.accession_number)

    make_admin("mary")
    patch(:update, params: { id: number.id, collection_number: params })
    assert_no_flash
  end

  def test_update_merge
    collection_number_count = CollectionNumber.count
    obs1 = observations(:agaricus_campestris_obs)
    obs2 = observations(:coprinus_comatus_obs)
    num1 = collection_numbers(:agaricus_campestris_coll_num)
    num2 = collection_numbers(:coprinus_comatus_coll_num)
    num1.update(name: "Joe Schmoe")
    assert_users_equal(rolf, num1.user)
    assert_users_equal(rolf, num2.user)
    assert_obj_list_equal([num1], obs1.collection_numbers)
    assert_obj_list_equal([num2], obs2.collection_numbers)
    params = {
      name: num1.name,
      number: num1.number
    }
    login("rolf")
    patch(:update, params: { id: num2.id, collection_number: params })
    assert_flash_text(/Merged Rolf Singer 1 into Joe Schmoe 07-123a./)
    assert(collection_number_count - 1, CollectionNumber.count)
    new_num = obs1.reload.collection_numbers.first
    assert_obj_list_equal([new_num], obs1.collection_numbers)
    assert_obj_list_equal([new_num], obs2.reload.collection_numbers)
    assert_equal("Joe Schmoe", new_num.name)
    assert_equal("07-123a", new_num.number)
    # Make sure it updates the herbarium record which shared the old
    # collection number.
    assert_equal(
      new_num.format_name,
      herbarium_records(:coprinus_comatus_rolf_spec).accession_number
    )
  end

  def test_update_redirect
    obs   = observations(:detailed_unknown_obs)
    num   = obs.collection_numbers.first
    query = Query.lookup_and_save(:CollectionNumber, :all)
    q     = query.id.alphabetize
    login(obs.user.login)
    params = {
      id: num.id,
      collection_number: { name: num.name, number: num.number }
    }

    # Prove that update keeps query param when returning to observation.
    patch(:update, params: params.merge(back: obs.id, q: q))
    assert_redirected_to(observation_path(obs.id, q: q))

    # Prove that update can return to show with query intact.
    patch(:update, params: params.merge(back: "show", q: q))
    assert_redirected_to(collection_number_path(num.id, q: q))

    # Prove that update can return to index_collection_number with query intact.
    patch(:update, params: params.merge(back: "index", q: q))
    assert_redirected_to(
      collection_numbers_index_collection_number_path(id: num.id, q: q)
    )
  end

  def test_remove_observation
    obs1 = observations(:agaricus_campestris_obs)
    obs2 = observations(:coprinus_comatus_obs)
    num1 = collection_numbers(:agaricus_campestris_coll_num)
    num2 = collection_numbers(:coprinus_comatus_coll_num)
    assert_obj_list_equal([num1], obs1.collection_numbers)
    assert_obj_list_equal([num2], obs2.collection_numbers)

    # Make sure user must be logged in.
    get(:remove_observation, id: num1.id, obs: obs1.id)
    assert_obj_list_equal([num1], obs1.reload.collection_numbers)

    # Make sure only obs's owner can remove num from it.
    login("mary")
    get(:remove_observation, id: num1.id, obs: obs1.id)
    assert_obj_list_equal([num1], obs1.reload.collection_numbers)

    # Make sure badly-formed queries don't crash.
    login("rolf")
    get(:remove_observation)
    get(:remove_observation, id: -1)
    get(:remove_observation, id: num1.id)
    get(:remove_observation, id: num1.id, obs: "bogus")
    get(:remove_observation, id: num1.id, obs: obs2.id)
    assert_obj_list_equal([num1], obs1.reload.collection_numbers)
    assert_obj_list_equal([num2], obs2.reload.collection_numbers)

    # Removing num from last obs destroys it.
    get(:remove_observation, id: num1.id, obs: obs1.id)
    assert_empty(obs1.reload.collection_numbers)
    assert_nil(CollectionNumber.safe_find(num1.id))

    # Removing num from one of two obs does not destroy it.
    num2.add_observation(obs1)
    assert_obj_list_equal([num2], obs1.reload.collection_numbers)
    assert_obj_list_equal([num2], obs2.reload.collection_numbers)
    get(:remove_observation, id: num2.id, obs: obs2.id)
    assert_obj_list_equal([num2], obs1.reload.collection_numbers)
    assert_empty(obs2.reload.collection_numbers)
    assert_not_nil(CollectionNumber.safe_find(num2.id))

    # Finally make sure admin has permission.
    make_admin("mary")
    get(:remove_observation, id: num2.id, obs: obs1.id)
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
    post(:remove_observation, id: nums[1].id, obs: obs.id, q: q)
    assert_redirected_to(observation_path(obs.id, q: q))
  end

  def test_destroy
    obs1 = observations(:agaricus_campestris_obs)
    obs2 = observations(:coprinus_comatus_obs)
    num1 = collection_numbers(:agaricus_campestris_coll_num)
    num2 = collection_numbers(:coprinus_comatus_coll_num)
    num1.add_observation(obs2)
    assert_obj_list_equal([num1], obs1.reload.collection_numbers)
    assert_obj_list_equal([num1, num2], obs2.reload.collection_numbers, :sort)

    # Make sure user must be logged in.
    delete(:destroy, id: num1.id)
    assert_obj_list_equal([num1], obs1.reload.collection_numbers)

    # Make sure only owner obs can destroy num from it.
    login("mary")
    delete(:destroy, id: num1.id)
    assert_obj_list_equal([num1], obs1.reload.collection_numbers)

    # Make sure badly-formed queries don't crash.
    login("rolf")
    delete(:destroy, id: "bogus")
    assert_obj_list_equal([num1], obs1.reload.collection_numbers)

    # Owner can destroy it.
    delete(:destroy, id: num1.id)
    assert_empty(obs1.reload.collection_numbers)
    assert_obj_list_equal([num2], obs2.reload.collection_numbers)
    assert_nil(CollectionNumber.safe_find(num1.id))

    # Admin can destroy it.
    make_admin("mary")
    delete(:destroy, id: num2.id)
    assert_empty(obs1.reload.collection_numbers)
    assert_empty(obs2.reload.collection_numbers)
    assert_nil(CollectionNumber.safe_find(num2.id))
  end

  def test_destroy_redirect
    obs   = observations(:detailed_unknown_obs)
    nums  = obs.collection_numbers
    query = Query.lookup_and_save(:CollectionNumber, :all)
    q     = query.id.alphabetize
    login(obs.user.login)
    assert_operator(nums.length, :>, 1)

    # Prove by default it goes back to index.
    delete(:destroy, id: nums[0].id)
    assert_redirected_to(action: :index_collection_number)

    # Prove that it keeps query param intact when returning to index.
    delete(:destroy, id: nums[1].id, q: q)
    assert_redirected_to(action: :index_collection_number, q: q)
  end
end

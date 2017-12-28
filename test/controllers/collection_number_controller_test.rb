require "test_helper"

class CollectionNumberControllerTest < FunctionalTestCase
  def test_collection_index
    get_with_dump(:list_collection_numbers)
    assert_template(:list_collection_numbers)
  end

  def test_observation_index_with_one_collection_number
    obs = observations(:minimal_unknown_obs)
    assert_equal(1, obs.collection_numbers.count)
    get_with_dump(:observation_index, id: obs.id)
    assert_template(:list_collection_numbers)
    assert_no_flash
  end

  def test_observation_index_with_multiple_collection_numbers
    obs = observations(:detailed_unknown_obs)
    assert_operator(obs.collection_numbers.count, :>, 1)
    get_with_dump(:observation_index, id: obs.id)
    assert_template(:list_collection_numbers)
    assert_no_flash
  end

  def test_observation_index_with_no_collection_numbers
    obs = observations(:strobilurus_diminutivus_obs)
    assert_empty(obs.collection_numbers)
    get_with_dump(:observation_index, id: obs.id)
    assert_template(:list_collection_numbers)
    assert_flash_text(/no matching collection numbers found/i)
  end

  def test_collection_number_search
    numbers = CollectionNumber.where("name like '%singer%'")
    assert_operator(numbers.count, :>, 1)
    get(:collection_number_search, pattern: "Singer")
    assert_response(:success)
    assert_template("list_collection_numbers")
    # In results, expect 1 row per collection_number.
    assert_select(".results tr", numbers.count)
  end

  def test_collection_number_search_with_one_collection_number_index
    numbers = CollectionNumber.where("name like '%neighbor%'")
    assert_equal(1, numbers.count)
    get_with_dump(:collection_number_search, pattern: "neighbor")
    query_record = QueryRecord.last
    assert_redirected_to(action: :show_collection_number,
                         id: numbers.first.id, q: query_record.id.alphabetize)
    assert_no_flash
  end

  def test_index_collection_number
    query = Query.lookup_and_save(:CollectionNumber, :all, users: rolf)
    assert_operator(query.num_results, :>, 1)
    get(:index_collection_number, q: query.record.id.alphabetize)
    assert_response(:success)
    assert_template("list_collection_numbers")
    # In results, expect 1 row per collection_number.
    assert_select(".results tr", query.num_results)
  end

  def test_show_collection_number
    get(:show_collection_number)
    get(:show_collection_number, id: "bogus")

    number = collection_numbers(:detailed_unknown_coll_num_two)
    get_with_dump(:show_collection_number, id: number.id)
  end

  def test_next_and_prev_collection_number
    query = Query.lookup_and_save(:CollectionNumber, :all, users: rolf)
    assert_operator(query.num_results, :>, 1)
    number1 = query.results[0]
    number2 = query.results[1]
    q = query.record.id.alphabetize

    get(:next_collection_number, id: number1.id, q: q)
    assert_redirected_to(action: :show_collection_number, id: number2.id, q: q)

    get(:prev_collection_number, id: number2.id, q: q)
    assert_redirected_to(action: :show_collection_number, id: number1.id, q: q)
  end

  def test_create_collection_number
    get(:create_collection_number)
    get(:create_collection_number, id: "bogus")

    obs = observations(:coprinus_comatus_obs)
    get(:create_collection_number, id: obs.id)
    assert_response(:redirect)

    login("mary")
    get(:create_collection_number, id: obs.id)
    assert_response(:redirect)

    login("rolf")
    get_with_dump(:create_collection_number, id: obs.id)
    assert_response(:success)
    assert_template("create_collection_number", partial: "_rss_log")
    assert(assigns(:collection_number))

    make_admin("mary")
    get(:create_collection_number, id: obs.id)
    assert_response(:success)
  end

  def test_create_collection_number_post
    collection_number_count = CollectionNumber.count
    obs = observations(:strobilurus_diminutivus_obs)
    assert_false(obs.specimen)
    assert_empty(obs.collection_numbers)
    params = {
      name: "  Some  Person <spam>  ",
      number: "  71-1234-c <spam>   "
    }

    post(:create_collection_number, id: obs.id, collection_number: params)
    assert_equal(collection_number_count, CollectionNumber.count)
    assert_redirected_to(controller: :account, action: :login)

    login("mary")
    post(:create_collection_number, id: obs.id, collection_number: params)
    assert_equal(collection_number_count, CollectionNumber.count)
    assert_flash_text(/permission denied/i)

    login("rolf")
    post(:create_collection_number, id: obs.id,
                                    collection_number: params.except(:name))
    assert_flash_text(/missing.*name/i)
    assert_equal(collection_number_count, CollectionNumber.count)
    post(:create_collection_number, id: obs.id,
                                    collection_number: params.except(:number))
    assert_flash_text(/missing.*number/i)
    assert_equal(collection_number_count, CollectionNumber.count)
    post(:create_collection_number, id: obs.id, collection_number: params)
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

  def test_create_collection_number_post_twice
    collection_number_count = CollectionNumber.count
    obs = observations(:strobilurus_diminutivus_obs)
    assert_empty(obs.collection_numbers)
    params = {
      name: "John Doe",
      number: "1234"
    }

    login("rolf")
    post(:create_collection_number, id: obs.id, collection_number: params)
    assert_equal(collection_number_count + 1, CollectionNumber.count)
    assert_no_flash
    number = CollectionNumber.last
    assert_obj_list_equal([number], obs.reload.collection_numbers)

    post(:create_collection_number, id: obs.id, collection_number: params)
    assert_equal(collection_number_count + 1, CollectionNumber.count)
    assert_flash_text(/shared/i)
    assert_obj_list_equal([number], obs.reload.collection_numbers)
  end

  def test_create_collection_number_post_already_used
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
    post(:create_collection_number, id: obs2.id, collection_number: params)
    assert_equal(collection_number_count, CollectionNumber.count)
    assert_flash_text(/shared/i)
    assert_equal(1, obs1.reload.collection_numbers.count)
    assert_equal(3, obs2.reload.collection_numbers.count)
    assert_equal(2, number.reload.observations.count)
    assert_includes(obs2.collection_numbers, number)
    assert_includes(number.observations, obs2)
  end

  def test_create_collection_number_redirect
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
    get(:create_collection_number, params)
    assert_select("form[action*='number/#{obs.id}?q=#{q}']")

    # Prove that post keeps query params intact.
    post(:create_collection_number, params)
    assert_redirected_to(obs.show_link_args.merge(q: q))
  end

  def test_edit_collection_number
    get(:edit_collection_number)
    get(:edit_collection_number, id: "bogus")

    number = collection_numbers(:coprinus_comatus_coll_num)
    get(:edit_collection_number, id: number.id)
    assert_response(:redirect)

    login("mary")
    get(:edit_collection_number, id: number.id)
    assert_response(:redirect)

    login("rolf")
    get_with_dump(:edit_collection_number, id: number.id)
    assert_response(:success)
    assert_template("edit_collection_number", partial: "_rss_log")
    assert_objs_equal(number, assigns(:collection_number))

    make_admin("mary")
    get(:edit_collection_number, id: number.id)
    assert_response(:success)
  end

  def test_edit_collection_number_post
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
      name:   "  New   Name <spam>  ",
      number: "  69-abc <spam>  "
    }

    post(:edit_collection_number, id: number.id, collection_number: params)
    assert_redirected_to(controller: :account, action: :login)

    login("mary")
    post(:edit_collection_number, id: number.id, collection_number: params)
    assert_flash_text(/permission denied/i)

    login("rolf")
    post(:edit_collection_number, id: number.id,
                                  collection_number: params.merge(name: ""))
    assert_flash_text(/missing.*name/i)
    assert_not_equal("new number", number.reload.number)

    post(:edit_collection_number, id: number.id,
                                  collection_number: params.merge(number: ""))
    assert_flash_text(/missing.*number/i)
    assert_not_equal("New Name", number.reload.name)

    post(:edit_collection_number, id: number.id, collection_number: params)
    assert_no_flash
    assert_response(:redirect)
    assert_equal("New Name", number.reload.name)
    assert_equal("69-abc", number.number)
    assert_in_delta(Time.zone.now, number.updated_at, 1.minute)
    assert_equal("New Name 69-abc", number.reload.format_name)
    assert_equal("New Name 69-abc", record1.reload.accession_number)
    assert_equal(old_nybg_accession, record2.reload.accession_number)

    make_admin("mary")
    post(:edit_collection_number, id: number.id, collection_number: params)
    assert_no_flash
  end

  def test_edit_collection_number_post_merge
    collection_number_count = CollectionNumber.count
    obs1 = observations(:agaricus_campestris_obs)
    obs2 = observations(:coprinus_comatus_obs)
    num1 = collection_numbers(:agaricus_campestris_coll_num)
    num2 = collection_numbers(:coprinus_comatus_coll_num)
    num1.update_attributes(name: "Joe Schmoe")
    assert_users_equal(rolf, num1.user)
    assert_users_equal(rolf, num2.user)
    assert_obj_list_equal([num1], obs1.collection_numbers)
    assert_obj_list_equal([num2], obs2.collection_numbers)
    params = {
      name: num1.name,
      number: num1.number
    }
    login("rolf")
    post(:edit_collection_number, id: num2.id, collection_number: params)
    assert_flash_text(/Merged Rolf Singer 1 into Joe Schmoe 07-123a./)
    assert(collection_number_count - 1, CollectionNumber.count)
    new_num = obs1.reload.collection_numbers.first
    assert_obj_list_equal([new_num], obs1.collection_numbers)
    assert_obj_list_equal([new_num], obs2.reload.collection_numbers)
    assert_equal("Joe Schmoe", new_num.name)
    assert_equal("07-123a", new_num.number)
    # Make sure it updates the herbarium record which shared the old
    # collection number.
    assert_equal(new_num.format_name,
      herbarium_records(:coprinus_comatus_rolf_spec).accession_number)
  end

  def test_edit_collection_number_redirect
    obs   = observations(:detailed_unknown_obs)
    num   = obs.collection_numbers.first
    query = Query.lookup_and_save(:CollectionNumber, :all)
    q     = query.id.alphabetize
    login(obs.user.login)
    params = {
      id: num.id,
      collection_number: { name: num.name, number: num.number }
    }

    # Prove that GET passes "back" and query param through to form.
    get(:edit_collection_number, params.merge(back: "foo", q: q))
    assert_select("form[action*='collection_number/#{num.id}?back=foo&q=#{q}']")

    # Prove that POST keeps query param when returning to observation.
    post(:edit_collection_number, params.merge(back: obs.id, q: q))
    assert_redirected_to(obs.show_link_args.merge(q: q))

    # Prove that POST can return to show_collection_number with query intact.
    post(:edit_collection_number, params.merge(back: "show", q: q))
    assert_redirected_to(num.show_link_args.merge(q: q))

    # Prove that POST can return to index_collection_number with query intact.
    post(:edit_collection_number, params.merge(back: "index", q: q))
    assert_redirected_to(action: :index_collection_number, id: num.id, q: q)
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

    # Make sure only owner obs can remove num from it.
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
    assert_redirected_to(obs.show_link_args.merge(q: q))
  end

  def test_destroy_collection_number
    obs1 = observations(:agaricus_campestris_obs)
    obs2 = observations(:coprinus_comatus_obs)
    num1 = collection_numbers(:agaricus_campestris_coll_num)
    num2 = collection_numbers(:coprinus_comatus_coll_num)
    num1.add_observation(obs2)
    assert_obj_list_equal([num1], obs1.reload.collection_numbers)
    assert_obj_list_equal([num1,num2], obs2.reload.collection_numbers, :sort)

    # Make sure user must be logged in.
    get(:destroy_collection_number, id: num1.id)
    assert_obj_list_equal([num1], obs1.reload.collection_numbers)

    # Make sure only owner obs can destroy num from it.
    login("mary")
    get(:destroy_collection_number, id: num1.id)
    assert_obj_list_equal([num1], obs1.reload.collection_numbers)

    # Make sure badly-formed queries don't crash.
    login("rolf")
    get(:destroy_collection_number)
    get(:destroy_collection_number, id: "bogus")
    assert_obj_list_equal([num1], obs1.reload.collection_numbers)

    # Owner can destroy it.
    get(:destroy_collection_number, id: num1.id)
    assert_empty(obs1.reload.collection_numbers)
    assert_obj_list_equal([num2], obs2.reload.collection_numbers)
    assert_nil(CollectionNumber.safe_find(num1.id))

    # Admin can destroy it.
    make_admin("mary")
    get(:destroy_collection_number, id: num2.id)
    assert_empty(obs1.reload.collection_numbers)
    assert_empty(obs2.reload.collection_numbers)
    assert_nil(CollectionNumber.safe_find(num2.id))
  end

  def test_destroy_collection_number_redirect
    obs   = observations(:detailed_unknown_obs)
    nums  = obs.collection_numbers
    query = Query.lookup_and_save(:CollectionNumber, :all)
    q     = query.id.alphabetize
    login(obs.user.login)
    assert_operator(nums.length, :>, 1)

    # Prove by default it goes back to index.
    post(:destroy_collection_number, id: nums[0].id)
    assert_redirected_to(action: :index_collection_number)

    # Prove that it keeps query param intact when returning to index.
    post(:destroy_collection_number, id: nums[1].id, q: q)
    assert_redirected_to(action: :index_collection_number, q: q)
  end
end

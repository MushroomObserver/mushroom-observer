# frozen_string_literal: true

require("test_helper")

class CollectionNumbersControllerTest < FunctionalTestCase
  ##############################################################################
  # INDEX
  #
  def test_index
    login
    get(:index)

    assert_page_title(:COLLECTION_NUMBERS.l)
  end

  def test_index_with_query
    query = Query.lookup_and_save(:CollectionNumber, by_users: rolf)
    assert_operator(query.num_results, :>, 1)

    login
    get(:index, params: { q: @controller.q_param(query) })

    assert_response(:success)
    assert_page_title(:COLLECTION_NUMBERS.l)
    assert_displayed_filters("#{:query_by_users.l}: Rolf Singer")
    # In results, expect 1 row per collection_number.
    assert_select("#results tr", query.num_results)
  end

  def test_index_with_id_and_sorted
    last_number = CollectionNumber.last
    params = { id: last_number.id, by: :reverse_date }

    login
    get(:index, params: params)

    assert_response(:success)
    assert_page_title(:COLLECTION_NUMBERS.l)
    assert(
      collection_number_links.first[:href].
        start_with?(collection_number_path(last_number.id)),
      "Index's 1st CollectionNumber link should be link to the " \
      "last CollectionNumber"
    )
  end

  def test_index_observation_id_with_one_collection_number
    obs = observations(:coprinus_comatus_obs)
    assert_equal(1, obs.collection_numbers.count)

    login
    get(:index, params: { observation: obs.id })

    assert_no_flash
    assert_page_title(:COLLECTION_NUMBERS.l)
    assert_displayed_filters("#{:query_observations.l}: #{obs.id}")
  end

  def test_index_observation_id_with_multiple_collection_numbers
    obs = observations(:detailed_unknown_obs)
    assert_operator(obs.collection_numbers.count, :>, 1)

    login
    get(:index, params: { observation: obs.id })

    assert_no_flash
    assert_page_title(:COLLECTION_NUMBERS.l)
    assert_displayed_filters("#{:query_observations.l}: #{obs.id}")
  end

  def test_index_observation_id_with_no_hits
    obs = observations(:strobilurus_diminutivus_obs)
    assert_empty(obs.collection_numbers)

    login
    get(:index, params: { observation: obs.id })

    assert_page_title(:COLLECTION_NUMBERS.l)
    assert_flash_text(/no matching collection numbers found/i)
  end

  def test_index_pattern_str_matching_multiple_collection_numbers
    pattern = "Singer"
    numbers = CollectionNumber.where(CollectionNumber[:name] =~ pattern)
    assert(numbers.many?,
           "Test needs a pattern matching many collection numbers")

    login
    get(:index, params: { q: { model: :CollectionNumber, pattern: pattern } })

    assert_response(:success)
    assert_page_title(:COLLECTION_NUMBERS.l)
    assert_displayed_filters("#{:query_pattern.l}: #{pattern}")
    # Results should have 2 links per collection_number
    # a show link, and (because logged in user created the numbers)
    # an edit link
    assert_equal(numbers.count * 2, collection_number_links.count)
  end

  ##############################################################################
  # SHOW
  #
  def test_show_collection_number
    login
    # get(:show)
    get(:show, params: { id: "bogus" })

    number = collection_numbers(:detailed_unknown_coll_num_two)
    get(:show, params: { id: number.id })
  end

  def test_next_and_prev_collection_number
    query = Query.lookup_and_save(:CollectionNumber, by_users: rolf)
    assert_operator(query.num_results, :>, 1)
    number1 = query.results[0]
    number2 = query.results[1]
    q = @controller.q_param(query)

    login
    get(:show, params: { flow: :next, id: number1.id, q: q })
    assert_redirected_to(collection_number_path(id: number2.id,
                                                params: { q: q }))

    get(:show, params: { flow: :prev, id: number2.id, q: q })
    assert_redirected_to(collection_number_path(id: number1.id,
                                                params: { q: q }))
  end

  ##############################################################################
  # NEW
  #
  def test_new_collection_number
    get(:new)
    get(:new, params: { observation_id: "bogus" })

    obs = observations(:coprinus_comatus_obs)
    get(:new, params: { observation_id: obs.id })
    assert_response(:redirect)

    login("mary")
    get(:new, params: { observation_id: obs.id })
    assert_response(:redirect)

    login("rolf")
    get(:new, params: { observation_id: obs.id })
    assert_response(:success)
    assert_template("new", partial: "_matrix_box")
    assert(assigns(:collection_number))

    make_admin("mary")
    get(:new, params: { observation_id: obs.id })
    assert_response(:success)
  end

  def test_new_collection_number_turbo
    obs_id = observations(:coprinus_comatus_obs).id

    login("rolf")
    get(:new, params: { observation_id: obs_id }, format: :turbo_stream)
    assert_select("#modal_collection_number")
    # Verify CollectionNumberForm component rendered
    assert_select("form#collection_number_form")
    assert_select("input#collection_number_name")
    assert_select("input#collection_number_number")
  end

  ##############################################################################
  # EDIT
  #
  def test_edit_collection_number
    # get(:edit)
    get(:edit, params: { id: "bogus" })

    number = collection_numbers(:coprinus_comatus_coll_num)
    get(:edit, params: { id: number.id })
    assert_response(:redirect)

    login("mary")
    get(:edit, params: { id: number.id })
    assert_response(:redirect)

    login("rolf")
    get(:edit, params: { id: number.id })
    assert_response(:success)
    assert_template(:edit, partial: "_rss_log")
    assert_objs_equal(number, assigns(:collection_number))

    make_admin("mary")
    get(:edit, params: { id: number.id })
    assert_response(:success)
  end

  def test_edit_collection_number_turbo
    number = collection_numbers(:coprinus_comatus_coll_num)

    login("rolf")
    get(:edit, params: { id: number.id }, format: :turbo_stream)
    assert_template("shared/_modal_form")
    # Verify CollectionNumberForm component rendered
    assert_select("form#collection_number_form")
    assert_select("input#collection_number_name")
    assert_select("input#collection_number_number")
  end

  def test_edit_collection_number_multiple_obs
    # obs1 = observations(:agaricus_campestris_obs)
    obs2 = observations(:coprinus_comatus_obs)
    num1 = collection_numbers(:agaricus_campestris_coll_num)
    num1.add_observation(obs2)
    assert(num1.observations.size > 1)

    login
    get(:edit, params: { id: num1.id })
    assert_select(
      ".multiple-observations-warning",
      text: :edit_affects_multiple_observations.t(type: :collection_number)
    )
  end

  ##############################################################################
  # CREATE
  #
  def test_create_collection_number
    collection_number_count = CollectionNumber.count
    obs = observations(:strobilurus_diminutivus_obs)
    assert_false(obs.specimen)
    assert_empty(obs.collection_numbers)
    params = {
      name: "  Some  Person <spam>  ",
      number: "  71-1234-c <spam>   "
    }

    post(:create,
         params: { observation_id: obs.id, collection_number: params })
    assert_equal(collection_number_count, CollectionNumber.count)
    assert_redirected_to(new_account_login_path)

    login("mary")
    post(:create,
         params: { observation_id: obs.id, collection_number: params })
    assert_equal(collection_number_count, CollectionNumber.count)
    assert_flash_text(/permission denied/i)

    login("rolf")
    post(:create,
         params: { observation_id: obs.id,
                   collection_number: params.except(:name) })
    assert_flash_text(/missing.*name/i)
    assert_equal(collection_number_count, CollectionNumber.count)
    post(:create,
         params: { observation_id: obs.id,
                   collection_number: params.except(:number) })
    assert_flash_text(/missing.*number/i)
    assert_equal(collection_number_count, CollectionNumber.count)
    post(:create,
         params: { observation_id: obs.id, collection_number: params })
    assert_equal(collection_number_count + 1, CollectionNumber.count)
    assert_flash_success
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

  def test_create_collection_number_with_turbo
    obs = observations(:strobilurus_diminutivus_obs)
    user = obs.user
    params = {
      observation_id: obs.id,
      collection_number: {
        name: user.login,
        number: "1234"
      }
    }
    login(user.login)
    assert_difference("CollectionNumber.count", 1) do
      post(:create, params: params, format: :turbo_stream)
    end
  end

  def test_create_collection_number_turbo_validation_error
    obs = observations(:strobilurus_diminutivus_obs)
    login(obs.user.login)

    # Missing number should cause validation error
    params = {
      observation_id: obs.id,
      collection_number: { name: obs.user.legal_name, number: "" }
    }

    assert_no_difference("CollectionNumber.count") do
      post(:create, params: params, format: :turbo_stream)
    end

    # Should render turbo_stream to reload the modal form with errors
    assert_response(:success)
    assert_select("turbo-stream[action=?][target=?]",
                  "replace", "collection_number_form")
  end

  def test_create_collection_number_twice
    collection_number_count = CollectionNumber.count
    obs = observations(:strobilurus_diminutivus_obs)
    assert_empty(obs.collection_numbers)
    params = {
      name: "John Doe",
      number: "1234"
    }

    login("rolf")
    post(:create,
         params: { observation_id: obs.id, collection_number: params })
    assert_equal(collection_number_count + 1, CollectionNumber.count)
    assert_flash_success
    number = CollectionNumber.last
    assert_obj_arrays_equal([number], obs.reload.collection_numbers)

    post(:create,
         params: { observation_id: obs.id, collection_number: params })
    assert_equal(collection_number_count + 1, CollectionNumber.count)
    assert_flash_text(/shared/i)
    assert_obj_arrays_equal([number], obs.reload.collection_numbers)
  end

  def test_create_collection_number_already_used
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
    post(:create,
         params: { observation_id: obs2.id, collection_number: params })
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
    @controller.find_or_create_query(:CollectionNumber)
    params = {
      observation_id: obs.id,
      collection_number: { name: "John Doe", number: "31415" }
    }

    # Prove that query params are added to form action.
    login(obs.user.login)
    get(:new, params: params)
    assert_select(
      "form[action*='numbers?observation_id=#{obs.id}']"
    )
    assert_session_query_record_is_correct

    # Prove that post keeps query params intact.
    post(:create, params: params)
    assert_redirected_to(permanent_observation_path(id: obs.id))
    assert_session_query_record_is_correct
  end

  ##############################################################################
  # UPDATE
  #
  def test_update_collection_number
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

    collection_number = {
      name: "  New   Name <spam>  ",
      number: "  69-abc <spam>  "
    }
    params = { id: number.id, collection_number: }

    patch(:update, params:)
    assert_redirected_to(new_account_login_path)

    login("mary")
    patch(:update, params:)
    assert_flash_text(/permission denied/i)

    # Test turbo shows flash warning
    patch(:update, params:, format: :turbo_stream)
    assert_flash_text(/permission denied/i)
    assert_template("shared/_modal_flash_update")

    login("rolf")
    patch(:update, params: params.deep_merge(collection_number: { name: "" }))
    assert_flash_text(/missing.*name/i)
    assert_not_equal("new number", number.reload.number)

    patch(:update, params: params.deep_merge(collection_number: { number: "" }))
    assert_flash_text(/missing.*number/i)
    assert_not_equal("New Name", number.reload.name)

    patch(:update, params:)
    assert_flash_success
    assert_response(:redirect)
    assert_equal("New Name", number.reload.name)
    assert_equal("69-abc", number.number)
    assert_in_delta(Time.zone.now, number.updated_at, 1.minute)
    assert_equal("New Name 69-abc", number.reload.format_name)
    assert_equal("New Name 69-abc", record1.reload.accession_number)
    assert_equal(old_nybg_accession, record2.reload.accession_number)

    make_admin("mary")
    patch(:update,
          params: { id: number.id, collection_number: params })
    assert_flash_success
  end

  def test_update_collection_number_turbo_from_observation_page
    collection_number = collection_numbers(:coprinus_comatus_coll_num)
    observation = collection_number.observations.first
    login("rolf")

    params = {
      id: collection_number.id,
      back: observation.id.to_s,
      collection_number: {
        name: collection_number.name,
        number: "updated-number"
      }
    }

    patch(:update, params: params, format: :turbo_stream)

    assert_equal("updated-number", collection_number.reload.number)
    # Should render turbo_stream to update the collection_numbers section
    assert_response(:success)
    assert_select("turbo-stream[action=?][target=?]",
                  "replace", "observation_collection_numbers")
  end

  def test_update_collection_number_merge
    collection_number_count = CollectionNumber.count
    obs1 = observations(:agaricus_campestris_obs)
    obs2 = observations(:coprinus_comatus_obs)
    num1 = collection_numbers(:agaricus_campestris_coll_num)
    num2 = collection_numbers(:coprinus_comatus_coll_num)
    num1.update(name: "Joe Schmoe")
    assert_users_equal(rolf, num1.user)
    assert_users_equal(rolf, num2.user)
    assert_obj_arrays_equal([num1], obs1.collection_numbers)
    assert_obj_arrays_equal([num2], obs2.collection_numbers)
    params = {
      name: num1.name,
      number: num1.number
    }
    login("rolf")
    patch(:update,
          params: { id: num2.id, collection_number: params })
    assert_flash_text(/Merged Rolf Singer 1 into Joe Schmoe 07-123a./)
    assert(collection_number_count - 1, CollectionNumber.count)
    new_num = obs1.reload.collection_numbers.first
    assert_obj_arrays_equal([new_num], obs1.collection_numbers)
    assert_obj_arrays_equal([new_num], obs2.reload.collection_numbers)
    assert_equal("Joe Schmoe", new_num.name)
    assert_equal("07-123a", new_num.number)
    # Make sure it updates the herbarium record which shared the old
    # collection number.
    assert_equal(
      new_num.format_name,
      herbarium_records(:coprinus_comatus_rolf_spec).accession_number
    )
  end

  def test_update_collection_number_redirect
    obs   = observations(:detailed_unknown_obs)
    num   = obs.collection_numbers.first
    query = @controller.find_or_create_query(:CollectionNumber)
    q     = @controller.q_param(query)
    login(obs.user.login)
    params = {
      id: num.id,
      collection_number: { name: num.name, number: num.number }
    }

    # Prove that GET passes "back" and query param through to form.
    get(:edit, params: params.merge(back: "foo"))
    assert_select("form[action*='?back=foo']")
    assert_session_query_record_is_correct

    # Prove that POST keeps query param when returning to observation.
    patch(:update, params: params.merge(back: obs.id))
    assert_redirected_to(permanent_observation_path(id: obs.id))
    assert_session_query_record_is_correct

    # Prove that POST can return to show_collection_number with query intact.
    patch(:update, params: params.merge(back: "show"))
    assert_redirected_to(collection_number_path(id: num.id))
    assert_session_query_record_is_correct

    # Prove that POST can return to index_collection_number with query intact.
    patch(:update, params: params.merge(back: "index"))
    assert_redirected_to(collection_numbers_path(params: { id: num.id, q: }))
    assert_session_query_record_is_correct
  end

  ##############################################################################
  # DESTROY
  #
  def test_destroy_collection_number
    obs1 = observations(:agaricus_campestris_obs)
    obs2 = observations(:coprinus_comatus_obs)
    num1 = collection_numbers(:agaricus_campestris_coll_num)
    num2 = collection_numbers(:coprinus_comatus_coll_num)
    num1.add_observation(obs2)
    assert_obj_arrays_equal([num1], obs1.reload.collection_numbers)
    assert_obj_arrays_equal([num1, num2], obs2.reload.collection_numbers, :sort)

    # Make sure user must be logged in.
    delete(:destroy, params: { id: num1.id })
    assert_obj_arrays_equal([num1], obs1.reload.collection_numbers)

    # Make sure only owner obs can destroy num from it.
    login("mary")
    delete(:destroy, params: { id: num1.id })
    assert_obj_arrays_equal([num1], obs1.reload.collection_numbers)

    # Make sure badly-formed queries don't crash.
    login("rolf")
    # get(:destroy)
    delete(:destroy, params: { id: "bogus" })
    assert_obj_arrays_equal([num1], obs1.reload.collection_numbers)

    # Owner can destroy it.
    delete(:destroy, params: { id: num1.id })
    assert_empty(obs1.reload.collection_numbers)
    assert_obj_arrays_equal([num2], obs2.reload.collection_numbers)
    assert_nil(CollectionNumber.safe_find(num1.id))

    # Admin can destroy it.
    make_admin("mary")
    delete(:destroy, params: { id: num2.id })
    assert_empty(obs1.reload.collection_numbers)
    assert_empty(obs2.reload.collection_numbers)
    assert_nil(CollectionNumber.safe_find(num2.id))
  end

  def test_destroy_collection_number_redirect
    obs   = observations(:detailed_unknown_obs)
    nums  = obs.collection_numbers
    query = Query.lookup_and_save(:CollectionNumber)
    q     = @controller.q_param(query)
    login(obs.user.login)
    assert_operator(nums.length, :>, 1)

    # With back param set to observation ID, redirects to that observation.
    delete(:destroy, params: { id: nums[0].id, back: obs.id.to_s })
    assert_redirected_to(observation_path(obs))

    # With back: "index", explicitly requests redirect to index.
    delete(:destroy, params: { id: nums[1].id, back: "index", q: })
    assert_redirected_to(collection_numbers_path(params: { q: }))
  end

  # Bug: Destroy button on show page uses turbo_stream format, causing error
  # because @observation is nil. Should redirect with HTML format instead.
  def test_destroy_collection_number_turbo_from_show_page
    login("rolf")
    collection_number = collection_numbers(:coprinus_comatus_coll_num)
    collection_number_count = CollectionNumber.count

    # Simulate clicking Destroy button on the show page (back: "show")
    # The button incorrectly requests turbo_stream format
    delete(:destroy, params: { id: collection_number.id, back: "show" },
                     format: :turbo_stream)

    # Should still successfully destroy and redirect (not error)
    assert_equal(collection_number_count - 1, CollectionNumber.count)
    # Should redirect to index since we can't do turbo_stream update
    assert_redirected_to(collection_numbers_path)
  end

  # Destroy with back param set to observation ID redirects to that observation.
  def test_destroy_collection_number_with_back_to_observation
    # Create a collection_number with exactly one observation
    obs = observations(:minimal_unknown_obs)
    collection_number = CollectionNumber.create!(
      user: obs.user,
      name: obs.user.legal_name,
      number: "test-single",
      observations: [obs]
    )
    assert_equal(1, collection_number.observations.count)

    login(obs.user.login)
    collection_number_count = CollectionNumber.count

    # Destroy with back param set to observation ID (HTML format)
    delete(:destroy, params: { id: collection_number.id, back: obs.id.to_s })

    # Should successfully destroy and redirect to the observation
    assert_equal(collection_number_count - 1, CollectionNumber.count)
    assert_redirected_to(observation_path(obs))
  end

  # -------- Remove from observation (destroy with observation_id) ------------

  def test_remove_from_observation_must_be_logged_in
    obs = observations(:agaricus_campestris_obs)
    num = collection_numbers(:agaricus_campestris_coll_num)

    delete(:destroy, params: { id: num.id, observation_id: obs.id })
    assert_obj_arrays_equal([num], obs.reload.collection_numbers)
  end

  def test_remove_from_observation_only_owner_can_remove
    obs = observations(:agaricus_campestris_obs)
    num = collection_numbers(:agaricus_campestris_coll_num)

    login("mary") # owner is rolf
    delete(:destroy, params: { id: num.id, observation_id: obs.id })
    assert_obj_arrays_equal([num], obs.reload.collection_numbers)
  end

  def test_remove_from_observation_destroys_when_last_obs
    obs = observations(:agaricus_campestris_obs)
    num = collection_numbers(:agaricus_campestris_coll_num)

    login("rolf")
    delete(:destroy, params: { id: num.id, observation_id: obs.id })
    assert_empty(obs.reload.collection_numbers)
    assert_nil(CollectionNumber.safe_find(num.id))
  end

  def test_remove_from_observation_keeps_when_other_obs_remain
    obs1 = observations(:agaricus_campestris_obs)
    obs2 = observations(:coprinus_comatus_obs)
    num = collection_numbers(:coprinus_comatus_coll_num)
    num.add_observation(obs1)

    login("rolf")
    delete(:destroy, params: { id: num.id, observation_id: obs2.id })
    # num should still exist (attached to obs1) after removal from obs2
    assert_includes(obs1.reload.collection_numbers, num)
    assert_empty(obs2.reload.collection_numbers)
    assert_not_nil(CollectionNumber.safe_find(num.id))
  end

  def test_remove_from_observation_turbo_stream
    obs = observations(:agaricus_campestris_obs)
    num = collection_numbers(:agaricus_campestris_coll_num)

    login("rolf")
    delete(:destroy, params: { id: num.id, observation_id: obs.id },
                     format: :turbo_stream)
    assert_empty(obs.reload.collection_numbers)
  end

  ##############################################################################

  private

  def collection_number_links
    assert_select("#results a[href ^= '/collection_numbers/']")
  end
end

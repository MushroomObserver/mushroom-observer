require "test_helper"

class HerbariumRecordControllerTest < FunctionalTestCase
  def herbarium_record_params
    {
      id: observations(:strobilurus_diminutivus_obs).id,
      herbarium_record: {
        herbarium_name: rolf.preferred_herbarium.auto_complete_name,
        initial_det: "Strobilurus diminutivus det. Rolf Singer",
        accession_number: "NYBG 1234567",
        notes: "Some notes about this herbarium record"
      }
    }
  end

  def test_herbarium_index
    get_with_dump(:herbarium_index, id: herbaria(:nybg_herbarium).id)
    assert_template(:list_herbarium_records)
  end

  def test_herbarium_with_no_herbarium_records_index
    get_with_dump(:herbarium_index, id: herbaria(:dick_herbarium).id)
    assert_template(:list_herbarium_records)
    assert_flash_text(/No matching herbarium records found/)
  end

  def test_observation_index
    get_with_dump(:observation_index,
                  id: observations(:coprinus_comatus_obs).id)
    assert_template(:list_herbarium_records)
  end

  def test_observation_with_no_herbarium_records_index
    get_with_dump(:observation_index,
                  id: observations(:strobilurus_diminutivus_obs).id)
    assert_template(:list_herbarium_records)
    assert_flash_text(/No matching herbarium records found/)
  end

  def test_herbarium_record_search
    # Two herbarium_records match this pattern.
    pattern = "Coprinus comatus"
    get(:herbarium_record_search, pattern: pattern)
    assert_response(:success)
    assert_template("list_herbarium_records")
    # In results, expect 1 row per herbarium_record
    assert_select(".results tr", 2)
  end

  def test_herbarium_record_search_with_one_herbarium_record_index
    get_with_dump(:herbarium_record_search,
                  pattern: herbarium_records(:interesting_unknown).id)
    assert_response(:redirect)
    assert_no_flash
  end

  def test_index_herbarium_record
    get(:index_herbarium_record)
    assert_response(:success)
    assert_template("list_herbarium_records")
    # In results, expect 1 row per herbarium_record
    assert_select(".results tr", HerbariumRecord.all.size)
  end

  def test_show_herbarium_record_without_notes
    herbarium_record = herbarium_records(:coprinus_comatus_nybg_spec)
    assert(herbarium_record)
    get_with_dump(:show_herbarium_record, id: herbarium_record.id)
    assert_template(:show_herbarium_record, partial: "_rss_log")
  end

  def test_show_herbarium_record_with_notes
    herbarium_record = herbarium_records(:interesting_unknown)
    assert(herbarium_record)
    get_with_dump(:show_herbarium_record, id: herbarium_record.id)
    assert_template(:show_herbarium_record, partial: "_rss_log")
  end

  def test_next_and_prev_herbarium_record
    query = Query.lookup_and_save(:HerbariumRecord, :all)
    assert_operator(query.num_results, :>, 1)
    number1 = query.results[0]
    number2 = query.results[1]
    q = query.record.id.alphabetize

    get(:next_herbarium_record, id: number1.id, q: q)
    assert_redirected_to(action: :show_herbarium_record, id: number2.id, q: q)

    get(:prev_herbarium_record, id: number2.id, q: q)
    assert_redirected_to(action: :show_herbarium_record, id: number1.id, q: q)
  end

  def test_create_herbarium_record
    get(:create_herbarium_record, id: observations(:coprinus_comatus_obs).id)
    assert_response(:redirect)

    login("rolf")
    get_with_dump(:create_herbarium_record,
                  id: observations(:coprinus_comatus_obs).id)
    assert_template("create_herbarium_record", partial: "_rss_log")
    assert(assigns(:herbarium_record))
  end

  def test_create_herbarium_record_post
    login("rolf")
    herbarium_record_count = HerbariumRecord.count
    params = herbarium_record_params
    obs = Observation.find(params[:id])
    assert(!obs.specimen)
    post(:create_herbarium_record, params)
    assert_equal(herbarium_record_count + 1, HerbariumRecord.count)
    herbarium_record = HerbariumRecord.last
    assert_equal("The New York Botanical Garden",
                 herbarium_record.herbarium.name)
    assert_equal(params[:herbarium_record][:initial_det],
                 herbarium_record.initial_det)
    assert_equal(params[:herbarium_record][:accession_number],
                 herbarium_record.accession_number)
    assert_equal(rolf, herbarium_record.user)
    obs = Observation.find(params[:id])
    assert(obs.specimen)
    assert_response(:redirect)
  end

  def test_create_herbarium_record_post_new_herbarium
    mary = login("mary")
    herbarium_count = mary.curated_herbaria.count
    params = herbarium_record_params
    params[:herbarium_record][:herbarium_name] = mary.personal_herbarium_name
    post(:create_herbarium_record, params)
    mary = User.find(mary.id) # Reload user
    assert_equal(herbarium_count + 1, mary.curated_herbaria.count)
    herbarium = Herbarium.all.order("created_at DESC")[0]
    assert(herbarium.curators.member?(mary))
  end

  def test_create_herbarium_record_post_duplicate
    login("rolf")
    herbarium_record_count = HerbariumRecord.count
    params = herbarium_record_params
    existing = herbarium_records(:coprinus_comatus_nybg_spec)
    params[:herbarium_record][:herbarium_name]   = existing.herbarium.name
    params[:herbarium_record][:initial_det]      = existing.initial_det
    params[:herbarium_record][:accession_number] = existing.accession_number
    post(:create_herbarium_record, params)
    assert_equal(herbarium_record_count, HerbariumRecord.count)
    assert_flash_text(/already exists/i)
    assert_response(:redirect)
  end

  # I keep thinking only curators should be able to add herbarium_records.
  # However, for now anyone can.
  def test_create_herbarium_record_post_not_curator
    nybg = herbaria(:nybg_herbarium)
    obs  = observations(:strobilurus_diminutivus_obs)
    obs.update_attributes(user: dick)
    herbarium_record_count = HerbariumRecord.count
    params = herbarium_record_params
    params[:id] = obs.id
    params[:herbarium_record][:herbarium_name] = nybg.name

    login("mary")
    assert(!nybg.curators.member?(mary))
    assert(!obs.can_edit?(mary))
    post(:create_herbarium_record, params)
    assert_equal(herbarium_record_count, HerbariumRecord.count)
    assert_response(:redirect)
    assert_flash_text(/only curators can/i)
     
    login("dick")
    assert(!nybg.curators.member?(dick))
    assert(obs.can_edit?(dick))
    post(:create_herbarium_record, params)
    assert_equal(herbarium_record_count + 1, HerbariumRecord.count)
    assert_response(:redirect)
    assert_no_flash
  end

  def test_create_herbarium_record_redirect
    obs = observations(:coprinus_comatus_obs)
    query = Query.lookup_and_save(:HerbariumRecord, :all)
    q = query.id.alphabetize
    params = {
      id: obs.id,
      herbarium_record: { herbarium_name: obs.user.preferred_herbarium.auto_complete_name },
      q: q
    }

    # Prove that query params are added to form action.
    login(obs.user.login)
    get(:create_herbarium_record, params)
    assert_select("form[action*='create_herbarium_record/#{obs.id}?q=#{q}']")

    # Prove that post keeps query params intact.
    post(:create_herbarium_record, params)
    assert_redirected_to(obs.show_link_args.merge(q: q))
  end

  def test_edit_herbarium_record
    nybg = herbarium_records(:coprinus_comatus_nybg_spec)
    get_with_dump(:edit_herbarium_record, id: nybg.id)
    assert_response(:redirect)

    login("mary") # Non-curator
    get_with_dump(:edit_herbarium_record, id: nybg.id)
    assert_flash_text(/permission denied/i)
    assert_response(:redirect)

    login("rolf")
    get_with_dump(:edit_herbarium_record, id: nybg.id)
    assert_template(:edit_herbarium_record)

    make_admin("mary") # Non-curator, but an admin
    get_with_dump(:edit_herbarium_record, id: nybg.id)
    assert_template(:edit_herbarium_record)
  end

  def test_edit_herbarium_record_post
    login("rolf")
    nybg_rec    = herbarium_records(:coprinus_comatus_nybg_spec)
    nybg_user   = nybg_rec.user
    rolf_herb   = rolf.personal_herbarium
    params      = herbarium_record_params
    params[:id] = nybg_rec.id
    params[:herbarium_record][:herbarium_name] = rolf_herb.name
    assert_not_equal(rolf_herb, nybg_rec.herbarium)
    post(:edit_herbarium_record, params)
    nybg_rec.reload
    assert_equal(rolf_herb, nybg_rec.herbarium)
    assert_equal(nybg_user, nybg_rec.user)
    assert_equal(params[:herbarium_record][:initial_det],
                 nybg_rec.initial_det)
    assert_equal(params[:herbarium_record][:accession_number],
                 nybg_rec.accession_number)
    assert_equal(params[:herbarium_record][:notes], nybg_rec.notes)
    assert_response(:redirect)
  end

  def test_edit_herbarium_record_post_no_specimen
    login("rolf")
    nybg = herbarium_records(:coprinus_comatus_nybg_spec)
    post(:edit_herbarium_record, id: nybg.id)
    assert_template(:edit_herbarium_record)
  end

  def test_edit_herbarium_record_redirect
    obs   = observations(:detailed_unknown_obs)
    rec   = obs.herbarium_records.first
    query = Query.lookup_and_save(:HerbariumRecord, :all)
    q     = query.id.alphabetize
    make_admin("rolf")
    params = {
      id: rec.id,
      herbarium_record: {
        herbarium_name:   rec.herbarium.auto_complete_name,
        initial_det:      rec.initial_det,
        accession_number: rec.accession_number,
        notes:            rec.notes
      }
    }

    # Prove that GET passes "back" and query param through to form.
    get(:edit_herbarium_record, params.merge(back: "foo", q: q))
    assert_select("form[action*='herbarium_record/#{rec.id}?back=foo&q=#{q}']")

    # Prove that POST keeps query param when returning to observation.
    post(:edit_herbarium_record, params.merge(back: obs.id, q: q))
    assert_redirected_to(obs.show_link_args.merge(q: q))

    # Prove that POST can return to show_herbarium_record with query intact.
    post(:edit_herbarium_record, params.merge(back: "show", q: q))
    assert_redirected_to(rec.show_link_args.merge(q: q))

    # Prove that POST can return to index_herbarium_record with query intact.
    post(:edit_herbarium_record, params.merge(back: "index", q: q))
    assert_redirected_to(action: :index_herbarium_record, id: rec.id, q: q)
  end

  def test_remove_observation
    obs1 = observations(:agaricus_campestris_obs)
    obs2 = observations(:coprinus_comatus_obs)
    rec1 = obs1.herbarium_records.first
    rec2 = obs2.herbarium_records.first
    assert_true(obs1.herbarium_records.include?(rec1))
    assert_true(obs2.herbarium_records.include?(rec2))

    # Make sure user must be logged in.
    get(:remove_observation, id: rec1.id, obs: obs1.id)
    assert_true(obs1.reload.herbarium_records.include?(rec1))

    # Make sure only owner obs can remove rec from it.
    login("mary")
    get(:remove_observation, id: rec1.id, obs: obs1.id)
    assert_true(obs1.reload.herbarium_records.include?(rec1))

    # Make sure badly-formed queries don't crash.
    login("rolf")
    get(:remove_observation)
    get(:remove_observation, id: -1)
    get(:remove_observation, id: rec1.id)
    get(:remove_observation, id: rec1.id, obs: "bogus")
    get(:remove_observation, id: rec1.id, obs: obs2.id)
    assert_true(obs1.reload.herbarium_records.include?(rec1))
    assert_true(obs2.reload.herbarium_records.include?(rec2))

    # Removing rec from last obs destroys it.
    get(:remove_observation, id: rec1.id, obs: obs1.id)
    assert_empty(obs1.reload.herbarium_records)
    assert_nil(HerbariumRecord.safe_find(rec1.id))

    # Removing rec from one of two obs does not destroy it.
    rec2.add_observation(obs1)
    assert_true(obs1.reload.herbarium_records.include?(rec2))
    assert_true(obs2.reload.herbarium_records.include?(rec2))
    get(:remove_observation, id: rec2.id, obs: obs2.id)
    assert_true(obs1.reload.herbarium_records.include?(rec2))
    assert_false(obs2.reload.herbarium_records.include?(rec2))
    assert_not_nil(HerbariumRecord.safe_find(rec2.id))

    # Finally make sure admin has permission.
    make_admin("mary")
    get(:remove_observation, id: rec2.id, obs: obs1.id)
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
    post(:remove_observation, id: recs[1].id, obs: obs.id, q: q)
    assert_redirected_to(obs.show_link_args.merge(q: q))
  end

  def test_destroy_herbarium_record
    login("rolf")
    herbarium_record = herbarium_records(:interesting_unknown)
    params = { id: herbarium_record.id }
    herbarium_record_count = HerbariumRecord.count
    observations = herbarium_record.observations
    obs_rec_count = observations.map { |o| o.herbarium_records.count }.
                    reduce { |a, b| a + b }
    get(:destroy_herbarium_record, params)
    assert_equal(herbarium_record_count - 1, HerbariumRecord.count)
    observations.map(&:reload)
    assert_true(obs_rec_count > observations.
                map { |o| o.herbarium_records.count }.
                reduce { |a, b| a + b })
    assert_response(:redirect)
  end

  def test_destroy_herbarium_record_not_curator
    login("mary")
    herbarium_record = herbarium_records(:interesting_unknown)
    params = { id: herbarium_record.id }
    herbarium_record_count = HerbariumRecord.count
    get(:destroy_herbarium_record, params)
    assert_equal(herbarium_record_count, HerbariumRecord.count)
    assert_response(:redirect)
  end

  def test_destroy_herbarium_record_admin
    make_admin("mary")
    herbarium_record = herbarium_records(:interesting_unknown)
    params = { id: herbarium_record.id }
    herbarium_record_count = HerbariumRecord.count
    get(:destroy_herbarium_record, params)
    assert_equal(herbarium_record_count - 1, HerbariumRecord.count)
    assert_response(:redirect)
  end

  def test_destroy_herbarium_record_redirect
    obs   = observations(:detailed_unknown_obs)
    recs  = obs.herbarium_records
    query = Query.lookup_and_save(:HerbariumRecord, :all)
    q     = query.id.alphabetize
    assert_operator(recs.length, :>, 1)
    make_admin("rolf")

    # Prove by default it goes back to index.
    post(:destroy_herbarium_record, id: recs[0].id)
    assert_redirected_to(action: :index_herbarium_record)

    # Prove that it keeps query param intact when returning to index.
    post(:destroy_herbarium_record, id: recs[1].id, q: q)
    assert_redirected_to(action: :index_herbarium_record, q: q)
  end
end

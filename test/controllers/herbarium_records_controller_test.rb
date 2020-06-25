# frozen_string_literal: true

require "test_helper"

# Test HerbariumRecordsController and Views
class HerbariumRecordsControllerTest < FunctionalTestCase
  def herbarium_record_params
    {
      id: observations(:strobilurus_diminutivus_obs).id,
      herbarium_record: {
        herbarium_name: rolf.preferred_herbarium.auto_complete_name,
        initial_det: "Strobilurus diminutivus det. Rolf Singer",
        accession_number: "1234567",
        notes: "Some notes about this herbarium record"
      }
    }
  end

##### Read indices: test actions that list multiple records

  def test_index
    get(:index)
    assert_response(:success)
    assert_template("herbarium_records/index")
    assert_select("table tr", HerbariumRecord.count,
                  "There should be 1 row/record")
  end

  def test_herbarium_index
    get(:herbarium_index, id: herbaria(:nybg_herbarium).id)
    assert_template(:index)
  end

  def test_herbarium_index_with_no_records
    get(:herbarium_index, id: herbaria(:dick_herbarium).id)
    assert_template(:index)
    assert_flash_text(/No matching herbarium records found/)
  end

  def test_observation_index
    get(:observation_index,
                  id: observations(:coprinus_comatus_obs).id)
    assert_template(:index)
  end

  def test_observation_index_with_no_records
    get(:observation_index, id: observations(:strobilurus_diminutivus_obs).id)
    assert_template(:index)
    assert_flash_text(/No matching herbarium records found/)
  end

  def test_search
    # Two herbarium_records match this pattern.
    pattern = "Coprinus comatus"
    get(:herbarium_record_search, pattern: pattern)
    assert_response(:success)
    assert_template("herbarium_records/index")
    assert_select("table tr", HerbariumRecord.where(initial_det: pattern).size,
                  "There should be 1 row/record")
  end

  def test_search_with_one_record
    get(:herbarium_record_search,
        pattern: herbarium_records(:interesting_unknown).id)
    assert_response(:redirect)
    assert_no_flash
  end

##### Read show - test actions that display one record

  def test_show
    # record without notes
    get(:show, id: herbarium_records(:coprinus_comatus_nybg_spec).id)
    assert_template(:show, partial: "shared/log_item")

    # record with notes
    get(:show, id: herbarium_records(:interesting_unknown).id)
    assert_template(:show, partial: "shared/log_item")
  end

  def test_next_and_prev
    query = Query.lookup_and_save(:HerbariumRecord, :all)
    assert_operator(query.num_results, :>, 1)
    number1 = query.results[0]
    number2 = query.results[1]
    q = query.record.id.alphabetize

    get(:show_next, id: number1.id, q: q)
    assert_redirected_to(action: :show, id: number2.id, q: q)

    get(:show_prev, id: number2.id, q: q)
    assert_redirected_to(action: :show, id: number1.id, q: q)
  end

##### Create - test actions that create a record

  def test_new
    get(:new, id: observations(:coprinus_comatus_obs).id)
    assert_response(:redirect)

    login("rolf")
    get(:new, id: observations(:coprinus_comatus_obs).id)
    assert_template(:new, partial: "shared/log_item")
    assert(assigns(:herbarium_record))
  end

  def test_create
    login("rolf")
    herbarium_record_count = HerbariumRecord.count
    params = herbarium_record_params
    obs = Observation.find(params[:id])
    assert_not(obs.specimen)
    post(:create, params)

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

  def test_create_new_herbarium
    mary = login("mary")
    herbarium_count = mary.curated_herbaria.count
    params = herbarium_record_params
    params[:herbarium_record][:herbarium_name] = mary.personal_herbarium_name
    post(:create, params)
    mary = User.find(mary.id) # Reload user
    assert_equal(herbarium_count + 1, mary.curated_herbaria.count)
    herbarium = Herbarium.all.order("created_at DESC")[0]
    assert(herbarium.curators.member?(mary))
  end

  def test_create_duplicate
    login("rolf")
    herbarium_record_count = HerbariumRecord.count
    params = herbarium_record_params
    existing = herbarium_records(:coprinus_comatus_nybg_spec)
    params[:herbarium_record][:herbarium_name]   = existing.herbarium.name
    params[:herbarium_record][:initial_det]      = existing.initial_det
    params[:herbarium_record][:accession_number] = existing.accession_number
    post(:create, params)
    assert_equal(herbarium_record_count, HerbariumRecord.count)
    assert_flash_text(/already exists/i)
    assert_response(:redirect)
  end

  # I keep thinking only curators should be able to add herbarium_records.
  # However, for now anyone can.
  def test_create_not_curator
    nybg = herbaria(:nybg_herbarium)
    obs  = observations(:strobilurus_diminutivus_obs)
    obs.update(user: dick)
    herbarium_record_count = HerbariumRecord.count
    params = herbarium_record_params
    params[:id] = obs.id
    params[:herbarium_record][:herbarium_name] = nybg.name

    login("mary")
    assert_not(nybg.curators.member?(mary))
    assert_not(obs.can_edit?(mary))
    post(:create, params)
    assert_equal(herbarium_record_count, HerbariumRecord.count)
    assert_response(:redirect)
    assert_flash_text(/only curators can/i)

    login("dick")
    assert_not(nybg.curators.member?(dick))
    assert(obs.can_edit?(dick))
    post(:create, params)
    assert_equal(herbarium_record_count + 1, HerbariumRecord.count)
    assert_response(:redirect)
    assert_no_flash
  end

  def test_create_redirect
    obs = observations(:coprinus_comatus_obs)
    query = Query.lookup_and_save(:HerbariumRecord, :all)
    q = query.id.alphabetize
    params = {
      id: obs.id,
      herbarium_record: { herbarium_name:
                          obs.user.preferred_herbarium.auto_complete_name },
      q: q
    }

    # Prove that query params are added to form action.
    login(obs.user.login)
    get(:new, params)
    assert_select("form input", { type: "hidden", name: q, value: q })

    # Prove that post keeps query params intact.
    post(:create, params)
    assert_redirected_to(observation_path(obs, q: q))
  end

##### Update - test actions that modify a record

  def test_edit
    nybg = herbarium_records(:coprinus_comatus_nybg_spec)
    get(:edit, id: nybg.id)
    assert_response(:redirect)

    login("mary") # Non-curator
    get(:edit, id: nybg.id)
    assert_flash_text(/permission denied/i)
    assert_response(:redirect)

    login("rolf")
    get(:edit, id: nybg.id)
    assert_template(:edit)

    make_admin("mary") # Non-curator, but an admin
    get(:edit, id: nybg.id)
    assert_template(:edit)
  end

  def test_update
    login("rolf")
    nybg_rec    = herbarium_records(:coprinus_comatus_nybg_spec)
    nybg_user   = nybg_rec.user
    rolf_herb   = rolf.personal_herbarium
    params      = herbarium_record_params
    params[:id] = nybg_rec.id
    params[:herbarium_record][:herbarium_name] = rolf_herb.name
    assert_not_equal(rolf_herb, nybg_rec.herbarium)
    post(:update, params)
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

  def test_update_no_specimen
    login("rolf")
    nybg = herbarium_records(:coprinus_comatus_nybg_spec)
    post(:update, id: nybg.id)
    assert_template(:edit)
  end

  def test_change_redirect
    obs   = observations(:detailed_unknown_obs)
    rec   = obs.herbarium_records.first
    query = Query.lookup_and_save(:HerbariumRecord, :all)
    q     = query.id.alphabetize
    make_admin("rolf")
    params = {
      id: rec.id,
      herbarium_record: {
        herbarium_name: rec.herbarium.auto_complete_name,
        initial_det: rec.initial_det,
        accession_number: rec.accession_number,
        notes: rec.notes
      }
    }

    # Prove that :edit passes "back" and query param through to form.
    get(:edit, params.merge(back: "foo", q: q))
    assert_select("form input", { type: "hidden", name: "back", value: "foo" })
    assert_select("form input", { type: "hidden", name: "q", value: q })

    # Prove that :update keeps query param when returning to observation.
    post(:update, params.merge(back: obs.id, q: q))
    assert_redirected_to(observation_path(obs, q: q))

    # Prove that :update can return to :show with query intact.
    post(:update, params.merge(back: "show", q: q))
    assert_redirected_to(herbarium_record_path(rec, q: q))

    # Prove that :update can return to :index with query intact.
    post(:update, params.merge(back: "index", q: q))
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
    assert_redirected_to(observation_path(obs, q: q))
  end

#### Destroy - test actions that destroy a records

  def test_destroy
    login("rolf")
    herbarium_record = herbarium_records(:interesting_unknown)
    params = { id: herbarium_record.id }
    herbarium_record_count = HerbariumRecord.count
    observations = herbarium_record.observations
    obs_rec_count = observations.map { |o| o.herbarium_records.count }.
                    reduce { |a, b| a + b }
    delete(:destroy, params)

    assert_equal(herbarium_record_count - 1, HerbariumRecord.count)
    observations.map(&:reload)
    assert_true(obs_rec_count > observations.
                map { |o| o.herbarium_records.count }.
                reduce { |a, b| a + b })
    assert_response(:redirect)
    # assert_redirected_to(action: :index_herbarium_record)
    assert_redirected_to(herbarium_records_index_herbarium_record_path())
  end

  def test_destroy_not_curator
    login("mary")
    herbarium_record = herbarium_records(:interesting_unknown)
    params = { id: herbarium_record.id }
    herbarium_record_count = HerbariumRecord.count
    get(:destroy, params)
    assert_equal(herbarium_record_count, HerbariumRecord.count)
    assert_response(:redirect)
  end

  def test_destroy_admin
    make_admin("mary")
    herbarium_record = herbarium_records(:interesting_unknown)
    params = { id: herbarium_record.id }
    herbarium_record_count = HerbariumRecord.count
    get(:destroy, params)
    assert_equal(herbarium_record_count - 1, HerbariumRecord.count)
    assert_response(:redirect)
  end

  def test_destroy_redirect
    obs   = observations(:detailed_unknown_obs)
    recs  = obs.herbarium_records
    query = Query.lookup_and_save(:HerbariumRecord, :all)
    q     = query.id.alphabetize
    assert_operator(recs.length, :>, 1)
    make_admin("rolf")

    # Prove by default it goes back to index.
    post(:destroy, id: recs[0].id)
    assert_redirected_to(action: :index_herbarium_record)

    # Prove that it keeps query param intact when returning to index.
    post(:destroy, id: recs[1].id, q: q)
    assert_redirected_to(action: :index_herbarium_record, q: q)
  end
end

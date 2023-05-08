# frozen_string_literal: true

require("test_helper")

class HerbariumRecordsControllerTest < FunctionalTestCase
  def herbarium_record_params
    {
      observation_id: observations(:strobilurus_diminutivus_obs).id,
      herbarium_record: {
        herbarium_name: rolf.preferred_herbarium.auto_complete_name,
        initial_det: "Strobilurus diminutivus det. Rolf Singer",
        accession_number: "1234567",
        notes: "Some notes about this herbarium record"
      }
    }
  end

  # Test of index, with tests arranged as follows:
  # default subaction; then
  # other subactions in order of @index_subaction_param_keys
  def test_index
    login
    get(:index)

    assert_response(:success)
    assert_displayed_title("Fungarium Records by Name")
    # In results, expect 1 row per herbarium_record
    assert_select("#results tr", HerbariumRecord.count,
                  "Wrong number of Herbarium Records")
  end

  def test_index_by_non_default_sort_order
    by = "herbarium_name"

    login
    get(:index, params: { by: by })

    assert_displayed_title("Fungarium Records by Fungarium")
  end

  def test_index_by_initial_determination
    by = "initial_det"

    login
    get(:index, params: { by: by })

    assert_displayed_title("Fungarium Records by Initial Determination")
  end

  def test_index_by_accession_number
    by = "accession_number"

    login
    get(:index, params: { by: by })

    assert_displayed_title("Fungarium Records by Accession Number")
  end

  def test_index_pattern_with_multiple_matching_records
    # Two herbarium_records match this pattern.
    pattern = "Coprinus comatus"

    login
    get(:index, params: { pattern: pattern })

    assert_response(:success)
    assert_displayed_title("Fungarium Records Matching ‘#{pattern}’")
    # In results, expect 1 row per herbarium_record
    assert_select("#results tr", 2)
  end

  def test_index_pattern_with_one_matching_record
    record = herbarium_records(:interesting_unknown)

    login
    get(:index, params: { pattern: record.id })

    assert_redirected_to(herbarium_record_path(record.id))
    assert_no_flash
  end

  def test_index_herbarium_id_with_multiple_records
    herbarium = herbaria(:nybg_herbarium)

    login
    get(:index, params: { herbarium_id: herbarium.id })

    assert_displayed_title(
      :query_title_in_herbarium.l(types: :HERBARIUM_RECORDS.l,
                                  herbarium: herbarium.name)
    )
    # In results, expect 1 row per herbarium_record
    assert_select("#results tr",
                  HerbariumRecord.where(herbarium: herbarium).count)
  end

  def test_index_herbarium_id_no_matching_records
    herbarium = herbaria(:dick_herbarium)

    login
    get(:index, params: { herbarium_id: herbarium.id })

    assert_displayed_title(:list_objects.l(type: :HERBARIUM_RECORDS.l))
    assert_flash_text(:runtime_no_matches.l(type: :herbarium_records.l))
  end

  def test_index_observation_id
    obs = observations(:coprinus_comatus_obs)

    login
    get(:index, params: { observation_id: obs.id })

    assert_displayed_title(
      :query_title_for_observation.l(types: :HERBARIUM_RECORDS.l,
                                     observation: obs.unique_text_name)
    )
    #  "Fungarium Records attached to ‘#{obs.unique_text_name}’")
    assert_select("#results tr", obs.herbarium_records.size)
  end

  def test_index_observation_id_with_no_herbarium_records
    login

    obs = observations(:strobilurus_diminutivus_obs)
    get(:index, params: { observation_id: obs.id })

    assert_displayed_title(:list_objects.l(type: :HERBARIUM_RECORDS.l))
    assert_flash_text(:runtime_no_matches.l(type: :herbarium_records.l))
  end

  #########################################################

  def test_show_herbarium_record_without_notes
    herbarium_record = herbarium_records(:coprinus_comatus_nybg_spec)
    assert(herbarium_record)
    login
    get(:show, params: { id: herbarium_record.id })
    assert_template(:show)
    assert_template("shared/_matrix_box")
  end

  def test_show_herbarium_record_with_notes
    herbarium_record = herbarium_records(:interesting_unknown)
    assert(herbarium_record)
    login
    get(:show, params: { id: herbarium_record.id })
    assert_template(:show)
    assert_template("shared/_matrix_box")
  end

  def test_next_and_prev_herbarium_record
    query = Query.lookup_and_save(:HerbariumRecord, :all)
    assert_operator(query.num_results, :>, 1)
    number1 = query.results[0]
    number2 = query.results[1]
    q = query.record.id.alphabetize

    login
    get(:show, params: { id: number1.id, q: q, flow: :next })
    assert_redirected_to(herbarium_record_path(id: number2.id, q: q))

    get(:show, params: { id: number2.id, q: q, flow: :prev })
    assert_redirected_to(herbarium_record_path(id: number1.id, q: q))
  end

  def test_new_herbarium_record
    obs_id = observations(:coprinus_comatus_obs).id
    get(:new, params: { observation_id: obs_id })
    assert_response(:redirect)

    login("rolf")
    get(:new, params: { observation_id: obs_id })
    assert_template("new")
    assert_template("shared/_matrix_box")
    assert(assigns(:herbarium_record))
  end

  def test_create_herbarium_record
    login("rolf")
    herbarium_record_count = HerbariumRecord.count
    params = herbarium_record_params
    obs = Observation.find(params[:observation_id])
    assert_not(obs.specimen)
    post(:create, params: params)
    assert_equal(herbarium_record_count + 1, HerbariumRecord.count)
    herbarium_record = HerbariumRecord.last
    assert_equal("The New York Botanical Garden",
                 herbarium_record.herbarium.name)
    assert_equal(params[:herbarium_record][:initial_det],
                 herbarium_record.initial_det)
    assert_equal(params[:herbarium_record][:accession_number],
                 herbarium_record.accession_number)
    assert_equal(rolf, herbarium_record.user)
    obs = Observation.find(params[:observation_id])
    assert(obs.specimen)
    assert_response(:redirect)
  end

  def test_create_herbarium_record_new_herbarium
    mary = login("mary")
    herbarium_count = mary.curated_herbaria.count
    params = herbarium_record_params
    params[:herbarium_record][:herbarium_name] = mary.personal_herbarium_name
    post(:create, params: params)
    mary = User.find(mary.id) # Reload user
    assert_equal(herbarium_count + 1, mary.curated_herbaria.count)
    herbarium = Herbarium.all.order(created_at: :desc)[0]
    assert(herbarium.curators.member?(mary))
  end

  def test_create_herbarium_record_duplicate
    login("rolf")
    herbarium_record_count = HerbariumRecord.count
    params = herbarium_record_params
    existing = herbarium_records(:coprinus_comatus_nybg_spec)
    params[:herbarium_record][:herbarium_name]   = existing.herbarium.name
    params[:herbarium_record][:initial_det]      = existing.initial_det
    params[:herbarium_record][:accession_number] = existing.accession_number
    post(:create, params: params)
    assert_equal(herbarium_record_count, HerbariumRecord.count)
    assert_flash_text(/already exists/i)
    assert_response(:redirect)
  end

  # I keep thinking only curators should be able to add herbarium_records.
  # However, for now anyone can.
  def test_create_herbarium_record_not_curator
    nybg = herbaria(:nybg_herbarium)
    obs  = observations(:strobilurus_diminutivus_obs)
    obs.update(user: dick)
    herbarium_record_count = HerbariumRecord.count
    params = herbarium_record_params
    params[:observation_id] = obs.id
    params[:herbarium_record][:herbarium_name] = nybg.name

    login("mary")
    assert_not(nybg.curators.member?(mary))
    assert_not(obs.can_edit?(mary))
    post(:create, params: params)
    assert_equal(herbarium_record_count, HerbariumRecord.count)
    assert_response(:redirect)
    assert_flash_text(/only curators can/i)

    login("dick")
    assert_not(nybg.curators.member?(dick))
    assert(obs.can_edit?(dick))
    post(:create, params: params)
    assert_equal(herbarium_record_count + 1, HerbariumRecord.count)
    assert_response(:redirect)
    assert_no_flash
  end

  def test_create_herbarium_record_redirect
    obs = observations(:coprinus_comatus_obs)
    query = Query.lookup_and_save(:HerbariumRecord, :all)
    q = query.id.alphabetize
    params = {
      observation_id: obs.id,
      herbarium_record: { herbarium_name:
                          obs.user.preferred_herbarium.auto_complete_name },
      q: q
    }

    # Prove that query params are added to form action.
    login(obs.user.login)
    get(:new, params: params)
    assert_select("form[action*='records?observation_id=#{obs.id}&q=#{q}']")

    # Prove that post keeps query params intact.
    post(:create, params: params)
    assert_redirected_to(permanent_observation_path(id: obs.id, q: q))
  end

  def test_edit_herbarium_record
    nybg = herbarium_records(:coprinus_comatus_nybg_spec)
    get(:edit, params: { id: nybg.id })
    assert_response(:redirect)

    login("mary") # Non-curator
    get(:edit, params: { id: nybg.id })
    assert_flash_text(/permission denied/i)
    assert_response(:redirect)

    login("rolf")
    get(:edit, params: { id: nybg.id })
    assert_template(:edit)

    make_admin("mary") # Non-curator, but an admin
    get(:edit, params: { id: nybg.id })
    assert_template(:edit)
  end

  def test_udpate_herbarium_record
    login("rolf")
    nybg_rec    = herbarium_records(:coprinus_comatus_nybg_spec)
    nybg_user   = nybg_rec.user
    rolf_herb   = rolf.personal_herbarium
    params      = herbarium_record_params
    params[:id] = nybg_rec.id
    params[:herbarium_record][:herbarium_name] = rolf_herb.name
    assert_not_equal(rolf_herb, nybg_rec.herbarium)
    post(:update, params: params)
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

  def test_update_herbarium_record_no_specimen
    login("rolf")
    nybg = herbarium_records(:coprinus_comatus_nybg_spec)
    post(:update, params: { id: nybg.id })
    assert_redirected_to(action: :edit)
  end

  def test_update_herbarium_record_redirect
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

    # Prove that GET passes "back" and query param through to form.
    get(:edit, params: params.merge(back: "foo", q: q))
    assert_select("form[action*='?back=foo&q=#{q}']")

    # Prove that POST keeps query param when returning to observation.
    post(:update, params: params.merge(back: obs.id, q: q))
    assert_redirected_to(permanent_observation_path(id: obs.id, q: q))

    # Prove that POST can return to show_herbarium_record with query intact.
    post(:update, params: params.merge(back: "show", q: q))
    assert_redirected_to(herbarium_record_path(id: rec.id, q: q))

    # Prove that POST can return to index_herbarium_record with query intact.
    post(:update, params: params.merge(back: "index", q: q))
    assert_redirected_to(herbarium_records_path(id: rec.id, q: q))
  end

  def test_destroy_herbarium_record
    login("rolf")
    herbarium_record = herbarium_records(:interesting_unknown)
    params = { id: herbarium_record.id }
    herbarium_record_count = HerbariumRecord.count
    observations = herbarium_record.observations
    obs_rec_count = observations.sum { |o| o.herbarium_records.count }
    delete(:destroy, params: params)
    assert_equal(herbarium_record_count - 1, HerbariumRecord.count)
    observations.map(&:reload)
    assert_true(
      obs_rec_count > observations.sum { |o| o.herbarium_records.count }
    )
    assert_response(:redirect)
  end

  def test_destroy_herbarium_record_not_curator
    login("mary")
    herbarium_record = herbarium_records(:interesting_unknown)
    params = { id: herbarium_record.id }
    herbarium_record_count = HerbariumRecord.count
    delete(:destroy, params: params)
    assert_equal(herbarium_record_count, HerbariumRecord.count)
    assert_response(:redirect)
  end

  def test_destroy_herbarium_record_admin
    make_admin("mary")
    herbarium_record = herbarium_records(:interesting_unknown)
    params = { id: herbarium_record.id }
    herbarium_record_count = HerbariumRecord.count
    delete(:destroy, params: params)
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
    delete(:destroy, params: { id: recs[0].id })
    assert_redirected_to(herbarium_records_path)

    # Prove that it keeps query param intact when returning to index.
    delete(:destroy, params: { id: recs[1].id, q: q })
    assert_redirected_to(herbarium_records_path(q: q))
  end
end

require "test_helper"

class HerbariumRecordControllerTest < FunctionalTestCase
  def herbarium_record_params
    {
      id: observations(:strobilurus_diminutivus_obs).id,
      herbarium_record: {
        herbarium_name: rolf.preferred_herbarium_name,
        initial_det: "Strobilurus diminutivus det. Rolf Singer",
        accession_number: "NYBG 1234567",
        notes: "Some notes about this herbarium record"
      }
    }
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

  def test_herbarium_index
    get_with_dump(:herbarium_index, id: herbaria(:nybg_herbarium).id)
    assert_template(:list_herbarium_records)
  end

  def test_herbarium_with_no_herbarium_records_index
    get_with_dump(:herbarium_index, id: herbaria(:dick_herbarium).id)
    assert_template(:list_herbarium_records)
    assert_flash(/No matching herbarium records found/)
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
    assert_flash(/No matching herbarium records found/)
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
    assert_equal(params[:herbarium_record][:herbarium_name],
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
    # Count the number of herbaria that mary is a curator for
    params = herbarium_record_params
    params[:herbarium_record][:herbarium_name] = mary.preferred_herbarium_name
    post(:create_herbarium_record, params)
    mary = User.find(mary.id) # Reload user
    assert_equal(herbarium_count + 1, mary.curated_herbaria.count)
    # herbarium = Herbarium.find(:all, order: "created_at DESC")[0] # Rails 3
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
    assert_flash(/already exists/i)
    assert_response(:redirect)
  end

  # I keep thinking only curators should be able to add herbarium_records.
  # However, for now anyone can.
  def test_create_herbarium_record_post_not_curator
    user = login("mary")
    nybg = herbaria(:nybg_herbarium)
    assert(!nybg.curators.member?(user))
    herbarium_record_count = HerbariumRecord.count
    params = herbarium_record_params
    params[:herbarium_record][:herbarium_name] = nybg.name
    post(:create_herbarium_record, params)
    nybg = Herbarium.find(nybg.id) # Reload herbarium
    assert(!nybg.curators.member?(user))
    assert_equal(herbarium_record_count + 1, HerbariumRecord.count)
    assert_response(:redirect)
  end

  def test_edit_herbarium_record
    nybg = herbarium_records(:coprinus_comatus_nybg_spec)
    get_with_dump(:edit_herbarium_record, id: nybg.id)
    assert_response(:redirect)

    login("mary") # Non-curator
    get_with_dump(:edit_herbarium_record, id: nybg.id)
    assert_flash(/permission denied/i)
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

  def test_edit_herbarium_record_add_remove_specimens
    nybg     = herbaria(:nybg_herbarium)
    rec      = herbarium_records(:coprinus_comatus_nybg_spec)
    obs      = rec.observations.first
    rolf_obs = observations(:agaricus_campestrus_obs)
    mary_obs = observations(:unknown_with_no_naming)
    katy_obs = observations(:amateur_obs)
    nybg.curators.delete(rolf)

    # roy is curator, rolf owns record and obs, mary is nothing
    assert(nybg.is_curator?(roy))
    assert(!nybg.is_curator?(rolf))
    assert(!nybg.is_curator?(mary))
    assert(rec.user == rolf)
    assert(obs.user == rolf)
    assert_equal(2, obs.herbarium_records.count)
    assert_empty(rolf_obs.herbarium_records)
    assert_empty(mary_obs.herbarium_records)
    assert_empty(katy_obs.herbarium_records)

    params = {
      id: rec.id, 
      herbarium_record: {
        herbarium_name:   rec.herbarium.name,
        initial_det:      rec.initial_det,
        accession_number: rec.accession_number
      }
    }

    login("mary")
    post(:edit_herbarium_record,
         params.merge(:"remove_observation_#{obs.id}" => "1"))
    assert_equal(2, obs.reload.herbarium_records.count)
    assert_flash_error
    post(:edit_herbarium_record, params.merge(add_observations: rolf_obs.id))
    assert_empty(rolf_obs.reload.herbarium_records)
    assert_flash_error
    post(:edit_herbarium_record, params.merge(add_observations: mary_obs.id))
    assert_empty(mary_obs.reload.herbarium_records)
    assert_flash_error
    rec.observations << mary_obs

    login("rolf")
    post(:edit_herbarium_record,
         params.merge(:"remove_observation_#{mary_obs.id}" => "1"))
    assert_not_empty(mary_obs.reload.herbarium_records)
    assert_flash_error
    post(:edit_herbarium_record,
         params.merge(:"remove_observation_#{obs.id}" => "1"))
    assert_equal(1, obs.reload.herbarium_records.count)
    assert_no_flash
    post(:edit_herbarium_record, params.merge(add_observations: katy_obs.id))
    assert_empty(katy_obs.reload.herbarium_records)
    assert_flash_error
    post(:edit_herbarium_record, params.merge(add_observations: rolf_obs.id))
    assert_not_empty(rolf_obs.reload.herbarium_records)
    assert_no_flash
    
    login("roy")
    post(:edit_herbarium_record, params.merge(
      :"remove_observation_#{rolf_obs.id}" => "1",
      :"remove_observation_#{mary_obs.id}" => "1"
    ))
    assert_empty(rolf_obs.reload.herbarium_records)
    assert_empty(mary_obs.reload.herbarium_records)
    assert_no_flash
    post(:edit_herbarium_record,
         params.merge(add_observations: "#{katy_obs.id} #{obs.id}"))
    assert_not_empty(katy_obs.reload.herbarium_records)
    assert_equal(2, obs.reload.herbarium_records.count)
    assert_no_flash
  end

  def test_destroy_herbarium_record
    login("rolf")
    params = { id: herbarium_records(:interesting_unknown).id }
    herbarium_record_count = HerbariumRecord.count
    herbarium_record = HerbariumRecord.find(params[:id])
    observations = herbarium_record.observations
    obs_spec_count = observations.map { |o| o.herbarium_records.count }.
                     reduce { |a, b| a + b }
    post(:destroy_herbarium_record, params)
    assert_equal(herbarium_record_count - 1, HerbariumRecord.count)
    observations.map(&:reload)
    assert_true(obs_spec_count > observations.
                map { |o| o.herbarium_records.count }.
                reduce { |a, b| a + b })
    assert_response(:redirect)
  end

  def test_destroy_herbarium_record_not_curator
    login("mary")
    params = { id: herbarium_records(:interesting_unknown).id }
    herbarium_record_count = HerbariumRecord.count
    post(:destroy_herbarium_record, params)
    assert_equal(herbarium_record_count, HerbariumRecord.count)
    assert_response(:redirect)
  end

  def test_destroy_herbarium_record_admin
    make_admin("mary")
    params = { id: herbarium_records(:interesting_unknown).id }
    herbarium_record_count = HerbariumRecord.count
    post(:destroy_herbarium_record, params)
    assert_equal(herbarium_record_count - 1, HerbariumRecord.count)
    assert_response(:redirect)
  end
end

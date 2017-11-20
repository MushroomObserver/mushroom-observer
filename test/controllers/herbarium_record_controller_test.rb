require "test_helper"

class HerbariumRecordControllerTest < FunctionalTestCase
  def assert_herbarium_record_index
    assert_template(:herbarium_record_index)
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
    assert_herbarium_record_index
  end

  def test_herbarium_with_one_herbarium_record_index
    get_with_dump(:herbarium_index, id: herbaria(:rolf_herbarium).id)
    assert_response(:redirect)
    assert_no_flash
  end

  def test_herbarium_with_no_herbarium_records_index
    get_with_dump(:herbarium_index, id: herbaria(:dick_herbarium).id)
    assert_response(:redirect)
    assert_flash(/no herbarium records/)
  end

  def test_observation_index
    get_with_dump(:observation_index,
                  id: observations(:coprinus_comatus_obs).id)
    assert_herbarium_record_index
  end

  def test_observation_with_one_herbarium_record_index
    get_with_dump(:observation_index,
                  id: observations(:detailed_unknown_obs).id)
    assert_response(:redirect)
    assert_no_flash
  end

  def test_observation_with_no_herbarium_records_index
    get_with_dump(:observation_index,
                  id: observations(:strobilurus_diminutivus_obs).id)
    assert_response(:redirect)
    assert_flash(/no herbarium records/)
  end

  def test_add_herbarium_record
    get(:add_herbarium_record, id: observations(:coprinus_comatus_obs).id)
    assert_response(:redirect)

    login("rolf")
    get_with_dump(:add_herbarium_record,
                  id: observations(:coprinus_comatus_obs).id)
    assert_template("add_herbarium_record", partial: "_rss_log")
    assert(assigns(:herbarium_label))
  end

  def add_herbarium_record_params
    {
      id: observations(:strobilurus_diminutivus_obs).id,
      herbarium_record: {
        herbarium_name: rolf.preferred_herbarium_name,
        herbarium_label:
          "Strobilurus diminutivus det. Rolf Singer - NYBG 1234567",
        "when(1i)"      => "2012",
        "when(2i)"      => "11",
        "when(3i)"      => "26",
        notes: "Some notes about this herbarium record"
      }
    }
  end

  def test_add_herbarium_record_post
    login("rolf")
    herbarium_record_count = HerbariumRecord.count
    params = add_herbarium_record_params
    obs = Observation.find(params[:id])
    assert(!obs.specimen)
    post(:add_herbarium_record, params)
    assert_equal(herbarium_record_count + 1, HerbariumRecord.count)
    herbarium_record = HerbariumRecord.all.order("created_at DESC")[0]
    assert_equal(params[:herbarium_record][:herbarium_name],
                 herbarium_record.herbarium.name)
    assert_equal(params[:herbarium_record][:herbarium_label],
                 herbarium_record.herbarium_label)
    assert_equal(params[:herbarium_record]["when(1i)"].to_i,
                 herbarium_record.when.year)
    assert_equal(params[:herbarium_record]["when(2i)"].to_i,
                 herbarium_record.when.month)
    assert_equal(params[:herbarium_record]["when(3i)"].to_i,
                 herbarium_record.when.day)
    assert_equal(rolf, herbarium_record.user)
    obs = Observation.find(params[:id])
    assert(obs.specimen)
    assert_response(:redirect)
  end

  def test_add_herbarium_record_post_new_herbarium
    mary = login("mary")
    herbarium_count = mary.curated_herbaria.count
    # Count the number of herbaria that mary is a curator for
    params = add_herbarium_record_params
    params[:herbarium_record][:herbarium_name] = mary.preferred_herbarium_name
    post(:add_herbarium_record, params)
    mary = User.find(mary.id) # Reload user
    assert_equal(herbarium_count + 1, mary.curated_herbaria.count)
    # herbarium = Herbarium.find(:all, order: "created_at DESC")[0] # Rails 3
    herbarium = Herbarium.all.order("created_at DESC")[0]
    assert(herbarium.curators.member?(mary))
  end

  def test_add_herbarium_record_post_duplicate
    login("rolf")
    herbarium_record_count = HerbariumRecord.count
    params = add_herbarium_record_params
    existing_herbarium_record = herbarium_records(:coprinus_comatus_nybg_spec)
    params[:herbarium_record][:herbarium_name] =
      existing_herbarium_record.herbarium.name
    params[:herbarium_record][:herbarium_label] =
      existing_herbarium_record.herbarium_label
    post(:add_herbarium_record, params)
    assert_equal(herbarium_record_count, HerbariumRecord.count)
    assert_flash(/already exists/i)
    assert_response(:success)
  end

  # I keep thinking only curators should be able to add herbarium_records.
  # However, for now anyone can.
  def test_add_herbarium_record_post_not_curator
    user = login("mary")
    nybg = herbaria(:nybg_herbarium)
    assert(!nybg.curators.member?(user))
    herbarium_record_count = HerbariumRecord.count
    params = add_herbarium_record_params
    params[:herbarium_record][:herbarium_name] = nybg.name
    post(:add_herbarium_record, params)
    nybg = Herbarium.find(nybg.id) # Reload herbarium
    assert(!nybg.curators.member?(user))
    assert_equal(herbarium_record_count + 1, HerbariumRecord.count)
    assert_response(:redirect)
  end

  def assert_edit_herbarium_record
    assert_template(:edit_herbarium_record)
  end

  def test_edit_herbarium_record
    nybg = herbarium_records(:coprinus_comatus_nybg_spec)
    get_with_dump(:edit_herbarium_record, id: nybg.id)
    assert_response(:redirect)

    login("mary") # Non-curator
    get_with_dump(:edit_herbarium_record, id: nybg.id)
    assert_flash(/unable to update herbarium record/i)
    assert_response(:redirect)

    login("rolf")
    get_with_dump(:edit_herbarium_record, id: nybg.id)
    assert_edit_herbarium_record

    make_admin("mary") # Non-curator, but an admin
    get_with_dump(:edit_herbarium_record, id: nybg.id)
    assert_edit_herbarium_record
  end

  def test_edit_herbarium_record_post
    login("rolf")
    nybg = herbarium_records(:coprinus_comatus_nybg_spec)
    herbarium = nybg.herbarium
    user = nybg.user
    params = add_herbarium_record_params
    params[:id] = nybg.id
    post(:edit_herbarium_record, params)
    herbarium_record = HerbariumRecord.find(nybg.id)
    assert_equal(herbarium, herbarium_record.herbarium)
    assert_equal(user, herbarium_record.user)
    assert_equal(params[:herbarium_record][:herbarium_label],
                 herbarium_record.herbarium_label)
    assert_equal(params[:herbarium_record]["when(1i)"].to_i,
                 herbarium_record.when.year)
    assert_equal(params[:herbarium_record]["when(2i)"].to_i,
                 herbarium_record.when.month)
    assert_equal(params[:herbarium_record]["when(3i)"].to_i,
                 herbarium_record.when.day)
    assert_equal(params[:herbarium_record][:notes], herbarium_record.notes)
    assert_equal(nybg.user, herbarium_record.user)
    assert_response(:redirect)
  end

  def test_edit_herbarium_record_post_no_specimen
    login("rolf")
    nybg = herbarium_records(:coprinus_comatus_nybg_spec)
    post(:edit_herbarium_record, id: nybg.id)
    assert_edit_herbarium_record
  end

  def test_delete_herbarium_record
    login("rolf")
    params = delete_herbarium_record_params
    herbarium_record_count = HerbariumRecord.count
    herbarium_record = HerbariumRecord.find(params[:id])
    observations = herbarium_record.observations
    obs_spec_count = observations.map { |o| o.herbarium_records.count }.
                     reduce { |a, b| a + b }
    post(:delete_herbarium_record, params)
    assert_equal(herbarium_record_count - 1, HerbariumRecord.count)
    observations.map(&:reload)
    assert_true(obs_spec_count > observations.
                map { |o| o.herbarium_records.count }.
                reduce { |a, b| a + b })
    assert_response(:redirect)
  end

  def test_delete_herbarium_record_not_curator
    login("mary")
    params = delete_herbarium_record_params
    herbarium_record_count = HerbariumRecord.count
    post(:delete_herbarium_record, params)
    assert_equal(herbarium_record_count, HerbariumRecord.count)
    assert_response(:redirect)
  end

  def test_delete_herbarium_record_admin
    make_admin("mary")
    params = delete_herbarium_record_params
    herbarium_record_count = HerbariumRecord.count
    post(:delete_herbarium_record, params)
    assert_equal(herbarium_record_count - 1, HerbariumRecord.count)
    assert_response(:redirect)
  end

  def delete_herbarium_record_params
    {
      id: herbarium_records(:interesting_unknown).id
    }
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

  def test_index_herbarium_record
    get(:index_herbarium_record)
    assert_response(:success)
    assert_template("list_herbarium_records")
    # In results, expect 1 row per herbarium_record
    assert_select(".results tr", HerbariumRecord.all.size)
  end
end

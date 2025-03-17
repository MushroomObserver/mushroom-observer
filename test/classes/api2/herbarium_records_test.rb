# frozen_string_literal: true

require("test_helper")
require("api2_extensions")

class API2::HerbariumRecordsTest < UnitTestCase
  include API2Extensions

  def test_basic_herbarium_record_get
    do_basic_get_test(HerbariumRecord)
  end

  # --------------------------------------
  #  :section: Herbarium Record Requests
  # --------------------------------------

  def params_get(**)
    { method: :get, action: :herbarium_record }.merge(**)
  end

  def test_getting_herbarium_records_created_at
    recs = HerbariumRecord.where(HerbariumRecord[:created_at].year.eq(2012))
    assert_not_empty(recs)
    assert_api_pass(params_get(created_at: "2012"))
    assert_api_results(recs)
  end

  def test_getting_herbarium_records_updated_at
    recs = HerbariumRecord.where(HerbariumRecord[:updated_at].year.eq(2017))
    assert_not_empty(recs)
    assert_api_pass(params_get(updated_at: "2017"))
    assert_api_results(recs)
  end

  def test_getting_herbarium_records_user
    recs = HerbariumRecord.where(user: mary)
    assert_not_empty(recs)
    assert_api_pass(params_get(user: "mary"))
    assert_api_results(recs)
  end

  def test_getting_herbarium_records_herbarium
    herb = herbaria(:nybg_herbarium)
    recs = herb.herbarium_records
    assert_not_empty(recs)
    assert_api_pass(params_get(herbarium: "The New York Botanical Garden"))
    assert_api_results(recs)
  end

  def test_getting_herbarium_records_observation
    obs  = observations(:detailed_unknown_obs)
    recs = obs.herbarium_records
    assert_not_empty(recs)
    assert_api_pass(params_get(observation: obs.id))
    assert_api_results(recs)
  end

  def test_getting_herbarium_records_notes_has
    recs = HerbariumRecord.where(HerbariumRecord[:notes].matches("%dried%"))
    assert_not_empty(recs)
    assert_api_pass(params_get(notes_has: "dried"))
    assert_api_results(recs)
  end

  def test_getting_herbarium_records_has_notes_no
    recs = HerbariumRecord.where(HerbariumRecord[:notes].blank)
    assert_not_empty(recs)
    assert_api_pass(params_get(has_notes: "no"))
    assert_api_results(recs)
  end

  def test_getting_herbarium_records_has_notes_yes
    recs = HerbariumRecord.where(HerbariumRecord[:notes].not_blank)
    assert_not_empty(recs)
    assert_api_pass(params_get(has_notes: "yes"))
    assert_api_results(recs)
  end

  def test_getting_herbarium_records_initial_det
    recs = HerbariumRecord.initial_det("Coprinus comatus")
    assert_not_empty(recs)
    assert_api_pass(params_get(initial_det: "Coprinus comatus"))
    assert_api_results(recs)
  end

  def test_getting_herbarium_records_initial_det_has
    recs = HerbariumRecord.where(
      HerbariumRecord[:initial_det].matches("%coprinus%")
    )
    assert_not_empty(recs)
    assert_api_pass(params_get(initial_det_has: "coprinus"))
    assert_api_results(recs)
  end

  def test_getting_herbarium_records_accession_number
    recs = HerbariumRecord.where(accession_number: "1234")
    assert_not_empty(recs)
    assert_api_pass(params_get(accession_number: "1234"))
    assert_api_results(recs)
  end

  def test_getting_herbarium_records_accession_number_has
    recs = HerbariumRecord.where(
      HerbariumRecord[:accession_number].matches("%23%")
    )
    assert_not_empty(recs)
    assert_api_pass(params_get(accession_number_has: "23"))
    assert_api_results(recs)
  end

  def test_posting_herbarium_records
    rolfs_obs         = observations(:strobilurus_diminutivus_obs)
    marys_obs         = observations(:detailed_unknown_obs)
    @obs              = rolfs_obs
    @herbarium        = herbaria(:fundis_herbarium)
    @initial_det      = "Absurdus namus"
    @accession_number = "13579a"
    @notes            = "i make good specimen"
    @user             = rolf
    params = {
      method: :post,
      action: :herbarium_record,
      api_key: @api_key.key,
      observation: @obs.id,
      herbarium: @herbarium.id,
      initial_det: @initial_det,
      accession_number: @accession_number,
      notes: @notes
    }
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.except(:observation))
    assert_api_fail(params.except(:herbarium))
    assert_api_fail(params.merge(observation: marys_obs.id))
    assert_api_pass(params)
    assert_last_herbarium_record_correct

    last_h_r = HerbariumRecord.last
    herbarium_record_count = HerbariumRecord.count
    rolfs_other_obs = observations(:stereum_hirsutum_1)
    assert_api_pass(params.merge(observation: rolfs_other_obs.id))
    assert_equal(herbarium_record_count, HerbariumRecord.count)
    assert_obj_arrays_equal([rolfs_obs, rolfs_other_obs],
                            last_h_r.observations.reorder(id: :asc), :sort)

    # Make sure it gives correct default for initial_det.
    assert_api_pass(params.except(:initial_det).merge(accession_number: "2"))
    last_h_r = HerbariumRecord.last
    assert_equal(rolfs_obs.name.text_name, last_h_r.initial_det)

    # Check default accession number if obs has no collection number.
    assert_api_pass(params.except(:accession_number))
    last_h_r = HerbariumRecord.last
    assert_equal("MO #{rolfs_obs.id}", last_h_r.accession_number)

    # Check default accession number if obs has one collection number.
    obs = observations(:coprinus_comatus_obs)
    num = obs.collection_numbers.reorder(id: :asc).first
    assert_operator(obs.collection_numbers.count, :==, 1)
    assert_api_pass(params.except(:accession_number).
                           merge(observation: obs.id))
    last_h_r = HerbariumRecord.last
    assert_equal(num.format_name, last_h_r.accession_number)

    # Check default accession number if obs has two collection numbers.
    # Also check that Rolf can add a record to Mary's obs if he's a curator.
    nybg = herbaria(:nybg_herbarium)
    assert_true(nybg.curator?(rolf))
    assert_operator(marys_obs.collection_numbers.count, :>, 1)
    assert_api_pass(params.except(:accession_number).
                      merge(observation: marys_obs.id, herbarium: nybg.id))
    last_h_r = HerbariumRecord.last
    assert_equal("MO #{marys_obs.id}", last_h_r.accession_number)
  end

  def test_patching_herbarium_records
    # Rolf owns the first record, and curates NYBG, but shouldn't be able to
    # touch Mary's record at an herbarium that he doesn't curate.
    rolfs_rec = herbarium_records(:coprinus_comatus_rolf_spec)
    nybgs_rec = herbarium_records(:interesting_unknown)
    marys_rec = herbarium_records(:fundis_record)
    fundis = herbaria(:fundis_herbarium)
    params = {
      method: :patch,
      action: :herbarium_record,
      api_key: @api_key.key,
      id: rolfs_rec.id,
      set_herbarium: "Fungal Diversity Survey",
      set_initial_det: " New name ",
      set_accession_number: " 1234 ",
      set_notes: " new notes "
    }
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.merge(id: marys_rec.id))
    assert_api_fail(params.merge(set_herbarium: ""))
    assert_api_fail(params.merge(set_initial_det: ""))
    assert_api_fail(params.merge(set_accession_number: ""))
    assert_api_pass(params)
    assert_objs_equal(fundis, rolfs_rec.reload.herbarium)
    assert_equal("New name", rolfs_rec.initial_det)
    assert_equal("1234", rolfs_rec.accession_number)
    assert_equal("new notes", rolfs_rec.notes)

    # This should fail because we don't allow merges via API2.
    assert_api_fail(params.merge(id: nybgs_rec.id))
    assert_api_pass(params.merge(id: nybgs_rec.id).except(:set_herbarium))
    assert_equal("New name", nybgs_rec.reload.initial_det)
    assert_equal("1234", nybgs_rec.accession_number)
    assert_equal("new notes", nybgs_rec.notes)

    # Rolfs_rec is now at fundis, so Rolf is not a curator, just owns rec.
    old_obs   = rolfs_rec.observations.reorder(id: :asc).first
    rolfs_obs = observations(:agaricus_campestris_obs)
    marys_obs = observations(:minimal_unknown_obs)
    params = {
      method: :patch,
      action: :herbarium_record,
      api_key: @api_key.key,
      id: rolfs_rec.id
    }
    assert_api_fail(params.merge(add_observation: marys_obs.id))
    assert_api_pass(params.merge(add_observation: rolfs_obs.id))
    assert_obj_arrays_equal([old_obs, rolfs_obs], rolfs_rec.reload.observations,
                            :sort)
    assert_api_pass(params.merge(remove_observation: old_obs.id))
    assert_obj_arrays_equal([rolfs_obs], rolfs_rec.reload.observations)
    assert_api_pass(params.merge(remove_observation: rolfs_obs.id))
    assert_nil(HerbariumRecord.safe_find(rolfs_rec.id))
  end

  def test_deleting_herbarium_records
    # Rolf should be able to destroy his own records and NYBG records but not
    # Mary's records at a different herbarium that he doesn't curate.
    rolfs_rec = herbarium_records(:coprinus_comatus_rolf_spec)
    nybgs_rec = herbarium_records(:interesting_unknown)
    marys_rec = herbarium_records(:fundis_record)
    params = {
      method: :delete,
      action: :herbarium_record,
      api_key: @api_key.key
    }
    assert_api_fail(params.except(:api_key))
    assert_api_pass(params.merge(id: rolfs_rec.id))
    assert_api_pass(params.merge(id: nybgs_rec.id))
    assert_api_fail(params.merge(id: marys_rec.id))
    assert_nil(HerbariumRecord.safe_find(rolfs_rec.id))
    assert_nil(HerbariumRecord.safe_find(nybgs_rec.id))
    assert_not_nil(HerbariumRecord.safe_find(marys_rec.id))
  end
end

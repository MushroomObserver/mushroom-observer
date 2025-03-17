# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::HerbariumRecords class to be included in QueryTest
class Query::HerbariumRecordsTest < UnitTestCase
  include QueryExtensions

  def test_herbarium_record_all
    expects = HerbariumRecord.index_order
    assert_query(expects, :HerbariumRecord)
  end

  def test_herbarium_record_id_in_set
    set = HerbariumRecord.order(id: :asc).last(3).pluck(:id)
    scope = HerbariumRecord.id_in_set(set)
    assert_query_scope(set, scope, :HerbariumRecord, id_in_set: set)
  end

  def test_herbarium_record_by_users
    expects = [herbarium_records(:fundis_record)]
    scope = HerbariumRecord.by_users(mary.id)
    assert_query_scope(expects, scope, :HerbariumRecord, by_users: mary)
  end

  def test_herbarium_record_observations
    obs = observations(:coprinus_comatus_obs)
    expects = HerbariumRecord.index_order.observations(obs)
    assert_query(expects, :HerbariumRecord, observations: obs.id)
  end

  def test_herbarium_record_herbaria
    nybg = herbaria(:nybg_herbarium)
    expects = HerbariumRecord.index_order.herbaria(nybg)
    assert_query(expects, :HerbariumRecord, herbaria: nybg.id)
  end

  def test_herbarium_record_has_notes
    expects = HerbariumRecord.index_order.has_notes
    assert(expects.include?(herbarium_records(:interesting_unknown)))
    assert_query(expects, :HerbariumRecord, has_notes: true)
    expects = HerbariumRecord.index_order.has_notes(false)
    assert(expects.include?(herbarium_records(:coprinus_comatus_nybg_spec)))
    assert_query(expects, :HerbariumRecord, has_notes: false)
  end

  def test_herbarium_record_notes_has
    expects = [herbarium_records(:interesting_unknown)]
    scope = HerbariumRecord.index_order.notes_has("dried")
    assert_query_scope(expects, scope, :HerbariumRecord, notes_has: "dried")
  end

  def test_herbarium_record_initial_det
    expects = [herbarium_records(:field_museum_record)]
    scope = HerbariumRecord.index_order.initial_det("Lichen")
    assert_query_scope(expects, scope, :HerbariumRecord, initial_det: "Lichen")
    assert_query_scope(expects, scope, :HerbariumRecord, initial_det: "lichen")
  end

  def test_herbarium_record_initial_det_has
    expects = [herbarium_records(:field_museum_record)]
    assert_query(expects, :HerbariumRecord, initial_det_has: "lichen")
  end

  def test_herbarium_record_accession
    expects = [herbarium_records(:interesting_unknown)]
    scope = HerbariumRecord.index_order.accession("1234")
    assert_query_scope(expects, scope, :HerbariumRecord, accession: "1234")

    expects = [herbarium_records(:coprinus_comatus_nybg_spec)]
    scope = HerbariumRecord.index_order.accession(4321)
    assert_query_scope(expects, scope, :HerbariumRecord, accession: "4321")
  end

  def test_herbarium_record_accession_has
    expects = [herbarium_records(:coprinus_comatus_rolf_spec)]
    scope = HerbariumRecord.index_order.accession_has("Rolf")
    assert_query_scope(expects, scope, :HerbariumRecord, accession_has: "Rolf")
  end

  def test_herbarium_record_pattern_search_notes
    expects = [herbarium_records(:interesting_unknown)]
    scope = HerbariumRecord.pattern("dried").index_order
    assert_query_scope(expects, scope, :HerbariumRecord, pattern: "dried")
  end

  def test_herbarium_record_pattern_search_not_findable
    expects = []
    scope = HerbariumRecord.pattern("no herbarium record has").index_order
    assert_query_scope(expects, scope,
                       :HerbariumRecord, pattern: "no herbarium record has")
  end

  def test_herbarium_record_pattern_search_initial_det
    expects = [herbarium_records(:agaricus_campestris_spec)]
    scope = HerbariumRecord.pattern("Agaricus").index_order
    assert_query_scope(expects, scope, :HerbariumRecord, pattern: "Agaricus")
  end

  def test_herbarium_record_pattern_search_accession_number
    expects = [herbarium_records(:interesting_unknown)]
    scope = HerbariumRecord.pattern("1234").index_order
    assert_query_scope(expects, scope, :HerbariumRecord, pattern: "1234")
  end

  def test_herbarium_record_pattern_search_blank
    expects = HerbariumRecord.index_order
    assert_query(expects, :HerbariumRecord, pattern: "")
  end
end

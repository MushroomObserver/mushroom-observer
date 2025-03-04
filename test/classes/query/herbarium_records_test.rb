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
    expects = HerbariumRecord.index_order.notes_has("dried")
    assert_query(expects, :HerbariumRecord, notes_has: "dried")
  end

  def test_herbarium_record_initial_dets
    expects = [herbarium_records(:field_museum_record)]
    assert_query(expects, :HerbariumRecord, initial_dets: "Lichen")
    expects = HerbariumRecord.index_order.initial_dets("Lichen")
    assert_query(expects, :HerbariumRecord, initial_dets: "Lichen")
    assert_query([], :HerbariumRecord, initial_dets: "lichen")
  end

  def test_herbarium_record_initial_det_has
    expects = [herbarium_records(:field_museum_record)]
    assert_query(expects, :HerbariumRecord, initial_det_has: "lichen")
  end

  def test_herbarium_record_accession_numbers
    expects = [herbarium_records(:interesting_unknown)]
    assert_query(expects, :HerbariumRecord, accession_numbers: "1234")
    expects = HerbariumRecord.index_order.accession_numbers("1234")
    assert_query(expects, :HerbariumRecord, accession_numbers: "1234")
    expects = [herbarium_records(:coprinus_comatus_nybg_spec)]
    assert_query(expects, :HerbariumRecord, accession_numbers: "4321")
    expects = HerbariumRecord.index_order.accession_numbers(4321)
    assert_query(expects, :HerbariumRecord, accession_numbers: 4321)
  end

  def test_herbarium_record_accession_number_has
    expects = [herbarium_records(:coprinus_comatus_rolf_spec)]
    assert_query(expects, :HerbariumRecord, accession_number_has: "Rolf")
  end

  def test_herbarium_record_pattern_search_notes
    expects = herbarium_record_pattern_search("dried")
    assert_query(expects, :HerbariumRecord, pattern: "dried")
  end

  def test_herbarium_record_pattern_search_not_findable
    assert_query([], :HerbariumRecord, pattern: "no herbarium record has this")
  end

  def test_herbarium_record_pattern_search_initial_det
    expects = herbarium_record_pattern_search("Agaricus")
    assert_query(expects, :HerbariumRecord, pattern: "Agaricus")
  end

  def test_herbarium_record_pattern_search_accession_number
    expects = herbarium_record_pattern_search("123a")
    assert_query(expects, :HerbariumRecord, pattern: "123a")
  end

  def test_herbarium_record_pattern_search_blank
    expects = HerbariumRecord.index_order
    assert_query(expects, :HerbariumRecord, pattern: "")
  end

  def herbarium_record_pattern_search(pattern)
    HerbariumRecord.index_order.where(
      HerbariumRecord[:initial_det].concat(HerbariumRecord[:accession_number]).
      concat(HerbariumRecord[:notes].coalesce("")).matches("%#{pattern}%")
    ).distinct
  end
end

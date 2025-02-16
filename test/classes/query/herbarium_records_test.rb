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

  def test_herbarium_record_for_observation
    obs = observations(:coprinus_comatus_obs)
    expects = HerbariumRecord.index_order.for_observation(obs)
    assert_query(expects, :HerbariumRecord, observation: obs.id)
  end

  def test_herbarium_record_in_herbarium
    nybg = herbaria(:nybg_herbarium)
    expects = HerbariumRecord.index_order.where(herbarium: nybg)
    assert_query(expects, :HerbariumRecord, herbarium: nybg.id)
  end

  def test_herbarium_record_pattern_search_notes
    expects = herbarium_record_pattern_search("dried")
    assert_query(expects, :HerbariumRecord, pattern: "dried")
  end

  def test_herbarium_record_pattern_search_not_findable
    assert_query([], :HerbariumRecord,
                 pattern: "no herbarium record has this")
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

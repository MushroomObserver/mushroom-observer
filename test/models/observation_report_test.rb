require "test_helper"
require "observation_report/base"
class ObservationReportTest < UnitTestCase
  def test_raw
    query = Query.lookup(:Observation, :all)
    report = ObservationReport::Raw.new(query: query)
    assert_not_empty(report.render)
  end

  def test_darwin
    query = Query.lookup(:Observation, :all)
    report = ObservationReport::Darwin.new(query: query)
    assert_not_empty(report.render)
  end

  def test_symbiota
    query = Query.lookup(:Observation, :all)
    report = ObservationReport::Symbiota.new(query: query)
    assert_not_empty(report.render)
  end

  def test_mycoflora
    query = Query.lookup(:Observation, :all)
    report = ObservationReport::Mycoflora.new(query: query)
    assert_not_empty(report.render)
  end

  def test_adolf
    query = Query.lookup(:Observation, :all)
    report = ObservationReport::Adolf.new(query: query)
    assert_not_empty(report.render)
  end
end

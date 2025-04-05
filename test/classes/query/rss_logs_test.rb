# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::RssLogs class to be included in QueryTest
class Query::RssLogsTest < UnitTestCase
  include QueryExtensions

  def test_rss_log_default_index
    ids = RssLog.order_by_default
    assert_query(ids, :RssLog)
  end

  def test_rss_log_in_set
    ids = [rss_logs(:species_list_rss_log).id,
           rss_logs(:name_rss_log).id]
    scope = RssLog.id_in_set(ids)
    assert_query_scope(ids, scope, :RssLog, id_in_set: ids)
  end

  def test_rss_log_type_all
    ids = RssLog.order_by_default
    scope = RssLog.type(:all).order_by_default
    assert_query_scope(ids, scope, :RssLog, type: :all)
  end

  def test_rss_log_type_species_list
    ids = [rss_logs(:species_list_rss_log).id]
    scope = RssLog.type(:species_list)
    assert_query_scope(ids, scope, :RssLog, type: :species_list)
  end

  def test_rss_log_type_species_list_project
    ids = [rss_logs(:project_rss_log),
           rss_logs(:species_list_rss_log)]
    scope = RssLog.type("species_list project").order_by_default
    assert_query_scope(ids, scope, :RssLog, type: "species_list project")
  end

  def test_rss_log_content_filter_has_specimen
    scope = RssLog.content_filters(has_specimen: true).order_by_default
    assert_query(scope, :RssLog, has_specimen: true)
    assert_equal(0, scope.where(Observation[:specimen].eq(false)).count)
  end

  def test_rss_log_content_filter_region
    region = "California, USA"
    scope = RssLog.content_filters(region:).order_by_default
    assert_query(scope, :RssLog, region:)
    # Check that the results got everything
    expect = RssLog.joins(:location).
             where(Location[:name].matches("%#{region}")).count
    assert(expect.positive?)
    assert_equal(expect,
                 scope.where(Location[:name].matches("%#{region}")).count)
    expect = RssLog.joins(:observation).
             where(Observation[:where].matches("%#{region}")).count
    assert(expect.positive?)
    assert_equal(expect,
                 scope.where(Observation[:where].matches("%#{region}")).count)
  end

  def test_rss_log_content_filter_lichen
    scope = RssLog.content_filters(lichen: true).order_by_default
    assert_query(scope, :RssLog, lichen: true)
    # Check that the results got everything. No name RssLogs for lichen yet.
    # expect = RssLog.joins(:name).
    #          where(Name[:lifeform].matches("%lichen%")).count
    # assert(expect.positive?)
    # assert_equal(expect,
    #              scope.where(Name[:lifeform].matches("%lichen%")).count)
    expect = RssLog.joins(:observation).
             where(Observation[:lifeform].matches("%lichen%")).count
    assert(expect.positive?)
    assert_equal(expect,
                 scope.where(Observation[:lifeform].matches("%lichen%")).count)
  end
end

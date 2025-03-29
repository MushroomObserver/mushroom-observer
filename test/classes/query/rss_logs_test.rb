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
end

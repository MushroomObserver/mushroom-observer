# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::RssLogs class to be included in QueryTest
class Query::RssLogsTest < UnitTestCase
  include QueryExtensions

  def test_rss_log_all
    ids = RssLog.index_order
    assert_query(ids, :RssLog)
  end

  def test_rss_log_type
    ids = [rss_logs(:species_list_rss_log).id]
    assert_query(ids, :RssLog, type: :species_list)
  end

  def test_rss_log_in_set
    rsslog_set_ids = [rss_logs(:species_list_rss_log).id,
                      rss_logs(:name_rss_log).id]
    assert_query(rsslog_set_ids, :RssLog, id_in_set: rsslog_set_ids)
  end
end

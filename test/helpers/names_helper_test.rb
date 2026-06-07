# frozen_string_literal: true

require("test_helper")

# Tests the surviving `NamesHelper` methods. The show-page helpers
# (`name_related_taxa_observation_links` chain, classification action
# links) moved into Tab POROs — their query-shape tests moved to
# `test/classes/tab/name/obs_link_query_integration_test.rb`.
class NamesHelperTest < ActionView::TestCase
  include NamesHelper

  def test_names_index_sorts_without_query
    sorts = names_index_sorts
    keys = sorts.map(&:first)

    assert_equal(%w[name created_at updated_at num_views], keys)
  end

  def test_names_index_sorts_with_rss_log_query_maps_updated_to_rss_log
    query = Query.lookup(Name, order_by: :rss_log)
    sorts = names_index_sorts(query: query)
    keys = sorts.map(&:first)

    assert_includes(keys, "rss_log")
    assert_not_includes(keys, "updated_at")
  end

  def test_names_index_sorts_with_non_rss_log_query_uses_updated_at
    query = Query.lookup(Name, order_by: :name)
    sorts = names_index_sorts(query: query)
    keys = sorts.map(&:first)

    assert_includes(keys, "updated_at")
    assert_not_includes(keys, "rss_log")
  end
end

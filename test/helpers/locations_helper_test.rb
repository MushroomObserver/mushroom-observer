# frozen_string_literal: true

require("test_helper")

# Tests for LocationsHelper. The integration / system tests exercise
# the link / count helpers transitively; the new local cases below
# pin `locations_index_sorts` branches that don't necessarily fire
# from index renders.
class LocationsHelperTest < ActionView::TestCase
  def test_locations_index_sorts_without_query
    sorts = locations_index_sorts

    keys = sorts.map(&:first)
    assert_equal(%w[name created_at updated_at num_views box_area], keys)
  end

  def test_locations_index_sorts_with_rss_log_query_maps_updated_to_rss_log
    query = Query.lookup(Location, order_by: :rss_log)
    sorts = locations_index_sorts(query: query)
    keys = sorts.map(&:first)

    # rss_log branch — "updated_at" slot uses rss_log instead.
    assert_includes(keys, "rss_log")
    assert_not_includes(keys, "updated_at")
  end

  def test_locations_index_sorts_with_non_rss_log_query_uses_updated_at
    query = Query.lookup(Location, order_by: :name)
    sorts = locations_index_sorts(query: query)
    keys = sorts.map(&:first)

    assert_includes(keys, "updated_at")
    assert_not_includes(keys, "rss_log")
  end
end

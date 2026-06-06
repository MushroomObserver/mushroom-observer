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

  # `find_species_list` is a defensive parser walking an arbitrary
  # query.params hash. Each `return nil unless ...` guard below
  # carves out a malformed-shape we don't want to crash on; these
  # tests pin each one explicitly.

  def test_find_species_list_with_object_lacking_params_method
    assert_nil(find_species_list(Object.new))
  end

  def test_find_species_list_with_non_hash_params
    fake_query = Struct.new(:params).new("not-a-hash")
    assert_nil(find_species_list(fake_query))
  end

  def test_find_species_list_with_missing_observation_query_subhash
    fake_query = Struct.new(:params).new({})
    assert_nil(find_species_list(fake_query))
  end

  def test_find_species_list_with_non_hash_observation_query
    fake_query = Struct.new(:params).new({ observation_query: "not-a-hash" })
    assert_nil(find_species_list(fake_query))
  end

  def test_find_species_list_with_non_array_species_lists
    fake_query = Struct.new(:params).new(
      { observation_query: { species_lists: "not-an-array" } }
    )
    assert_nil(find_species_list(fake_query))
  end

  def test_find_species_list_with_zero_species_lists
    fake_query = Struct.new(:params).new(
      { observation_query: { species_lists: [] } }
    )
    assert_nil(find_species_list(fake_query))
  end

  def test_find_species_list_with_multiple_species_lists
    fake_query = Struct.new(:params).new(
      { observation_query: { species_lists: [1, 2] } }
    )
    assert_nil(find_species_list(fake_query))
  end

  def test_show_obs_link_title_with_count
    loc = locations(:obs_default_location)
    expected = "#{:show_location_observations.t} (#{loc.observations.size})"

    assert_equal(expected, show_obs_link_title_with_count(loc),
                 "Expected observation count in parentheses after label")
  end

  def test_find_species_list_with_single_species_list_returns_it
    spl = species_lists(:first_species_list)
    fake_query = Struct.new(:params).new(
      { observation_query: { species_lists: [spl.id] } }
    )
    assert_equal(spl, find_species_list(fake_query))
  end
end

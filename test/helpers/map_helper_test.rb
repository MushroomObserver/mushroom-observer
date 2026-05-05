# frozen_string_literal: true

require("test_helper")

# Covers the small, branch-heavy helpers `MapHelper` exposes to
# the clustered-collection code path (issue #4159). Fuller coverage
# of `make_map` and its ERB consumers lives in the map_controller
# and view-level tests.
class MapHelperTest < ActionView::TestCase
  # ------------------------------------------------------------------
  # cluster_object_label
  # ------------------------------------------------------------------

  def test_cluster_object_label_prefers_text_name
    obj = Struct.new(:text_name, :display_name).new("Hypholoma", "ignored")
    assert_equal("Hypholoma", cluster_object_label(obj))
  end

  # Hits the `return obj.display_name.to_s if obj.respond_to?(:display_name)`
  # branch — objects that expose `display_name` but no `text_name`.
  def test_cluster_object_label_falls_back_to_display_name
    obj = Struct.new(:display_name).new("Amanita muscaria var. formosa")
    assert_equal("Amanita muscaria var. formosa",
                 cluster_object_label(obj))
  end

  # Hits the final `""` return — object exposes neither `text_name`
  # nor `display_name`.
  def test_cluster_object_label_empty_when_no_name_fields
    assert_equal("", cluster_object_label(Object.new))
  end

  def test_cluster_object_label_empty_when_text_name_is_blank
    obj = Struct.new(:text_name, :display_name).new("", "Display Name")
    assert_equal("Display Name", cluster_object_label(obj),
                 "blank text_name should fall through to display_name")
  end

  # ------------------------------------------------------------------
  # cluster_object_url
  # ------------------------------------------------------------------

  def test_cluster_object_url_for_observation
    obs = observations(:minimal_unknown_obs)
    url = cluster_object_url(obs, {})
    assert_match(%r{\A/observations/#{obs.id}(\?|\z)}, url,
                 "observation? objects should resolve to /observations/:id")
  end

  # Hits the `location_path(id: obj.id, params: params)` branch.
  # `Location` includes `Mappable::BoxMethods`, which defines
  # `observation? => false` and `location? => true`.
  def test_cluster_object_url_for_location
    loc = locations(:burbank)
    url = cluster_object_url(loc, {})
    assert_match(%r{\A/locations/#{loc.id}(\?|\z)}, url,
                 "location? objects should resolve to /locations/:id")
  end

  # Hits the final `""` branch — the object is neither an observation
  # nor a location (e.g., an unexpected shape that slipped through).
  def test_cluster_object_url_empty_for_unknown_shape
    assert_equal("", cluster_object_url(Object.new, {}))
  end

  def test_cluster_object_url_preserves_query_param
    obs = observations(:minimal_unknown_obs)
    url = cluster_object_url(obs, { query_param: { model: "Observation" } })
    assert_match(/q(%5B|\[)model(%5D|\])=Observation/, url,
                 "query_param arg should thread into the URL's q[model]")
  end
end

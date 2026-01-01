# frozen_string_literal: true

require "test_helper"

class MapTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @location = locations(:burbank)
    controller.request = ActionDispatch::TestRequest.create
  end

  def test_renders_map_div
    html = render(Components::Map.new(objects: [@location]))

    assert_html(html, "#map_div")
  end

  def test_renders_map_with_default_controller
    html = render(Components::Map.new(objects: [@location]))
    doc = Nokogiri::HTML(html)
    map_div = doc.at_css("#map_div")

    assert_equal("map", map_div["data-controller"])
  end

  def test_renders_map_without_controller_when_nil
    html = render(Components::Map.new(objects: [@location], controller: nil))
    doc = Nokogiri::HTML(html)
    map_div = doc.at_css("#map_div")

    assert_nil(map_div["data-controller"])
  end

  def test_renders_map_target_attribute
    html = render(Components::Map.new(objects: [@location]))
    doc = Nokogiri::HTML(html)
    map_div = doc.at_css("#map_div")

    assert_equal("mapDiv", map_div["data-map-target"])
  end

  def test_renders_map_type_as_info_by_default
    html = render(Components::Map.new(objects: [@location]))
    doc = Nokogiri::HTML(html)
    map_div = doc.at_css("#map_div")

    assert_equal("info", map_div["data-map-type"])
  end

  def test_renders_map_type_as_location_when_specified
    html = render(Components::Map.new(objects: [@location],
                                      map_type: "location"))
    doc = Nokogiri::HTML(html)
    map_div = doc.at_css("#map_div")

    assert_equal("location", map_div["data-map-type"])
  end

  def test_renders_editable_as_false_by_default
    html = render(Components::Map.new(objects: [@location]))
    doc = Nokogiri::HTML(html)
    map_div = doc.at_css("#map_div")

    assert_equal("false", map_div["data-editable"])
  end

  def test_renders_editable_as_true_when_specified
    html = render(Components::Map.new(objects: [@location], editable: true))
    doc = Nokogiri::HTML(html)
    map_div = doc.at_css("#map_div")

    assert_equal("true", map_div["data-editable"])
  end

  def test_renders_map_open_as_true_by_default
    html = render(Components::Map.new(objects: [@location]))
    doc = Nokogiri::HTML(html)
    map_div = doc.at_css("#map_div")

    assert_equal("true", map_div["data-map-open"])
  end

  def test_renders_map_open_as_false_when_specified
    html = render(Components::Map.new(objects: [@location], map_open: false))
    doc = Nokogiri::HTML(html)
    map_div = doc.at_css("#map_div")

    assert_equal("false", map_div["data-map-open"])
  end

  def test_renders_need_elevations_value_as_true_by_default
    html = render(Components::Map.new(objects: [@location]))
    doc = Nokogiri::HTML(html)
    map_div = doc.at_css("#map_div")

    assert_equal("true", map_div["data-need-elevations-value"])
  end

  def test_renders_need_elevations_value_as_false_when_specified
    html = render(Components::Map.new(objects: [@location],
                                      need_elevations_value: false))
    doc = Nokogiri::HTML(html)
    map_div = doc.at_css("#map_div")

    assert_equal("false", map_div["data-need-elevations-value"])
  end

  def test_renders_controls_as_json
    html = render(Components::Map.new(objects: [@location]))
    doc = Nokogiri::HTML(html)
    map_div = doc.at_css("#map_div")
    controls = JSON.parse(map_div["data-controls"])

    assert_includes(controls, "large_map")
    assert_includes(controls, "map_type")
  end

  def test_renders_collection_data
    html = render(Components::Map.new(objects: [@location]))
    doc = Nokogiri::HTML(html)
    map_div = doc.at_css("#map_div")

    assert_not_nil(map_div["data-collection"])
    collection = JSON.parse(map_div["data-collection"])
    assert(collection.key?("extents"))
    assert(collection.key?("sets"))
  end

  def test_renders_localization_data
    html = render(Components::Map.new(objects: [@location]))
    doc = Nokogiri::HTML(html)
    map_div = doc.at_css("#map_div")

    assert_not_nil(map_div["data-localization"])
    localization = JSON.parse(map_div["data-localization"])
    assert(localization.key?("nothing_to_map"))
    assert(localization.key?("observations"))
    assert(localization.key?("locations"))
  end

  def test_renders_nothing_to_map_when_no_objects
    html = render(Components::Map.new(objects: []))

    assert_includes(html, :runtime_map_nothing_to_map.t)
  end

  def test_renders_custom_nothing_to_map_message
    html = render(Components::Map.new(objects: [],
                                      nothing_to_map: "Custom message"))

    assert_includes(html, "Custom message")
  end

  def test_filters_unknown_locations
    unknown = Location.new(name: "Earth")
    html = render(Components::Map.new(objects: [unknown]))

    assert_includes(html, :runtime_map_nothing_to_map.t)
  end

  def test_renders_with_observation
    observation = observations(:detailed_unknown_obs)
    html = render(Components::Map.new(objects: [observation]))

    assert_html(html, "#map_div")
    assert_not_includes(html, :runtime_map_nothing_to_map.t)
  end

  def test_renders_with_custom_map_div_id
    html = render(Components::Map.new(objects: [@location],
                                      map_div: "custom_map"))
    doc = Nokogiri::HTML(html)

    assert_not_nil(doc.at_css("#custom_map"))
  end

  def test_renders_location_format
    html = render(Components::Map.new(objects: [@location]))
    doc = Nokogiri::HTML(html)
    map_div = doc.at_css("#map_div")

    assert_not_nil(map_div["data-location-format"])
  end
end

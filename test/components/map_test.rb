# frozen_string_literal: true

require "test_helper"

class MapTest < ComponentTestCase
  def setup
    super
    @location = locations(:burbank)
  end

  def test_renders_map_with_default_attributes
    html = render(Components::Map.new(objects: [@location]))

    # All default attributes on one element
    assert_html(
      html,
      "#map_div[data-controller='map']" \
      "[data-map-target='mapDiv']" \
      "[data-map-type='info']" \
      "[data-editable='false']" \
      "[data-map-open='true']" \
      "[data-need-elevations-value='true']" \
      "[data-location-format]"
    )
  end

  def test_renders_map_without_controller_when_nil
    html = render(Components::Map.new(objects: [@location], controller: nil))

    assert_no_html(html, "#map_div[data-controller]")
  end

  def test_renders_map_with_custom_options
    html = render(Components::Map.new(
                    objects: [@location],
                    map_type: "location",
                    editable: true,
                    map_open: false,
                    need_elevations_value: false,
                    map_div: "custom_map"
                  ))

    assert_html(
      html,
      "#custom_map" \
      "[data-map-type='location']" \
      "[data-editable='true']" \
      "[data-map-open='false']" \
      "[data-need-elevations-value='false']"
    )
  end

  def test_renders_json_data_attributes
    html = render(Components::Map.new(objects: [@location]))
    doc = Nokogiri::HTML(html)
    map_div = doc.at_css("#map_div")

    # Controls
    controls = JSON.parse(map_div["data-controls"])
    assert_includes(controls, "large_map")
    assert_includes(controls, "map_type")

    # Collection
    collection = JSON.parse(map_div["data-collection"])
    assert(collection.key?("extents"))
    assert(collection.key?("sets"))

    # Localization
    localization = JSON.parse(map_div["data-localization"])
    assert(localization.key?("nothing_to_map"))
    assert(localization.key?("observations"))
    assert(localization.key?("locations"))
  end

  def test_renders_nothing_to_map_when_no_mappable_objects
    # Empty objects
    html = render(Components::Map.new(objects: []))
    assert_html(html, "body", text: :runtime_map_nothing_to_map.t)

    # Unknown location (no coordinates)
    unknown = Location.new(name: "Earth")
    html = render(Components::Map.new(objects: [unknown]))
    assert_html(html, "body", text: :runtime_map_nothing_to_map.t)

    # Custom message
    html = render(Components::Map.new(objects: [],
                                      nothing_to_map: "Custom message"))
    assert_html(html, "body", text: "Custom message")
  end

  def test_renders_with_observation
    observation = observations(:detailed_unknown_obs)
    html = render(Components::Map.new(objects: [observation]))

    assert_html(html, "#map_div")
  end
end

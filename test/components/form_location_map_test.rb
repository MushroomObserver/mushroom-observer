# frozen_string_literal: true

require "test_helper"

class FormLocationMapTest < ComponentTestCase
  def test_default_map
    html = render_component(Components::FormLocationMap.new)

    # Map div structure
    assert_html(html, "div.form-map.collapse")

    # Default location type and format
    assert_html(html, "div.form-map",
                attribute: { "data-map-type" => "location",
                             "data-location-format" => "postal" })

    # Button group with toggle and clear buttons
    assert_html(html, "div.btn-group[role='group']")
    assert_html(html, "span.map-show")
    assert_html(html, "span.map-hide")
    assert_html(html, "button.map-clear[type='button']",
                attribute: { "data-map-target" => "mapClearBtn" })
  end

  def test_with_custom_id
    html = render_component(
      Components::FormLocationMap.new(id: "my_custom_map")
    )

    assert_html(html, "div#my_custom_map.form-map.collapse")
    assert_html(html, "div#my_custom_map[data-editable]",
                attribute: { "data-map-target" => "mapDiv" })
    assert_html(html, "button.map-toggle[type='button']",
                attribute: { "data-map-target" => "toggleMapBtn",
                             "aria-expanded" => "false",
                             "aria-controls" => "my_custom_map" })
  end

  def test_with_custom_map_type
    html = render_component(
      Components::FormLocationMap.new(map_type: "observation")
    )

    assert_html(html, "div.form-map",
                attribute: { "data-map-type" => "observation" })
  end

  def test_with_user_location_format
    user = users(:rolf)
    user.update!(location_format: "scientific")

    html = render_component(
      Components::FormLocationMap.new(user: user)
    )

    assert_html(html, "div.form-map",
                attribute: { "data-location-format" => "scientific" })
  end
end

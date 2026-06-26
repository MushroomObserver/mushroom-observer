# frozen_string_literal: true

require "test_helper"

class FormLocationMapTest < ComponentTestCase
  def test_default_map
    html = render_component(Components::Form::LocationMap.new)

    # Map div structure
    assert_html(html, "div.form-map.collapse")

    # Default location type and format
    assert_html(html, "div.form-map",
                attribute: { "data-map-type" => "location",
                             "data-location-format" => "postal" })

    # Button group with toggle and clear buttons. `role='group'` is
    # the ARIA contract; `.btn-group` is Bootstrap-styling decoration.
    assert_html(html, "div[role='group']")
    assert_html(html, "button[data-toggle='collapse']")
    assert_html(html, "button span.glyphicon")
    assert_html(html, "span.collapse-toggle-open",
                text: :form_observations_hide_map.l.as_displayed)
    assert_html(html, "span.collapse-toggle-closed",
                text: :form_observations_open_map.l.as_displayed)
    assert_html(html, "button.map-clear[type='button']",
                attribute: { "data-map-target" => "mapClearBtn" })
  end

  def test_with_custom_id
    html = render_component(
      Components::Form::LocationMap.new(id: "my_custom_map")
    )

    assert_html(html, "div#my_custom_map.form-map.collapse")
    assert_html(html, "div#my_custom_map[data-editable]",
                attribute: { "data-map-target" => "mapDiv" })
    assert_html(html,
                "button.map-toggle[type='button']" \
                "[data-toggle='collapse'][data-target='#my_custom_map']" \
                "[aria-expanded='false'][aria-controls='my_custom_map']",
                attribute: { "data-map-target" => "toggleMapBtn" })
    assert_html(html, "button[data-action=" \
                      "'map#toggleMap form-exif#showFields']")
  end

  def test_with_custom_map_type
    html = render_component(
      Components::Form::LocationMap.new(map_type: "observation")
    )

    assert_html(html, "div.form-map",
                attribute: { "data-map-type" => "observation" })
  end

  def test_with_user_location_format
    user = users(:rolf)
    user.update!(location_format: "scientific")

    html = render_component(
      Components::Form::LocationMap.new(user: user)
    )

    assert_html(html, "div.form-map",
                attribute: { "data-location-format" => "scientific" })
  end
end

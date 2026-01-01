# frozen_string_literal: true

require "test_helper"

class FormLocationMapTest < ComponentTestCase

  def test_renders_map_div_with_default_id
    html = render_component(Components::FormLocationMap.new)

    assert_html(html, "div.form-map.collapse")
  end

  def test_renders_map_div_with_custom_id
    html = render_component(
      Components::FormLocationMap.new(id: "my_custom_map")
    )

    assert_html(html, "div#my_custom_map.form-map.collapse")
  end

  def test_renders_map_with_data_attributes
    html = render_component(
      Components::FormLocationMap.new(id: "test_map")
    )

    # Check editable attribute exists and map-target is set
    assert_html(html, "div#test_map[data-editable]",
                attribute: { "data-map-target" => "mapDiv" })
  end

  def test_renders_map_with_default_location_type
    html = render_component(Components::FormLocationMap.new)

    assert_html(html, "div.form-map",
                attribute: { "data-map-type" => "location" })
  end

  def test_renders_map_with_custom_map_type
    html = render_component(
      Components::FormLocationMap.new(map_type: "observation")
    )

    assert_html(html, "div.form-map",
                attribute: { "data-map-type" => "observation" })
  end

  def test_renders_button_group
    html = render_component(Components::FormLocationMap.new)

    assert_html(html, "div.btn-group[role='group']")
  end

  def test_renders_toggle_button
    html = render_component(Components::FormLocationMap.new(id: "test_map"))

    assert_html(html, "button.map-toggle[type='button']",
                attribute: { "data-map-target" => "toggleMapBtn",
                             "aria-expanded" => "false",
                             "aria-controls" => "test_map" })
  end

  def test_renders_toggle_button_with_show_and_hide_labels
    html = render_component(Components::FormLocationMap.new)

    assert_html(html, "span.map-show")
    assert_html(html, "span.map-hide")
  end

  def test_renders_clear_button
    html = render_component(Components::FormLocationMap.new)

    assert_html(html, "button.map-clear[type='button']",
                attribute: { "data-map-target" => "mapClearBtn" })
  end

  def test_uses_default_location_format_without_user
    html = render_component(Components::FormLocationMap.new)

    assert_html(html, "div.form-map",
                attribute: { "data-location-format" => "postal" })
  end

  def test_uses_user_location_format_when_provided
    user = users(:rolf)
    user.update!(location_format: "scientific")

    html = render_component(
      Components::FormLocationMap.new(user: user)
    )

    assert_html(html, "div.form-map",
                attribute: { "data-location-format" => "scientific" })
  end
end

# frozen_string_literal: true

require "test_helper"

class FormLocationMapTest < UnitTestCase
  include ComponentTestHelper

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
    doc = Nokogiri::HTML(html)
    map_div = doc.at_css("div#test_map")

    # Boolean true renders as empty string in Phlex data attributes
    assert(map_div.key?("data-editable"))
    assert_equal("mapDiv", map_div["data-map-target"])
  end

  def test_renders_map_with_default_location_type
    html = render_component(Components::FormLocationMap.new)
    doc = Nokogiri::HTML(html)
    map_div = doc.at_css("div.form-map")

    assert_equal("location", map_div["data-map-type"])
  end

  def test_renders_map_with_custom_map_type
    html = render_component(
      Components::FormLocationMap.new(map_type: "observation")
    )
    doc = Nokogiri::HTML(html)
    map_div = doc.at_css("div.form-map")

    assert_equal("observation", map_div["data-map-type"])
  end

  def test_renders_button_group
    html = render_component(Components::FormLocationMap.new)

    assert_html(html, "div.btn-group[role='group']")
  end

  def test_renders_toggle_button
    html = render_component(Components::FormLocationMap.new(id: "test_map"))
    doc = Nokogiri::HTML(html)

    toggle_btn = doc.at_css("button.map-toggle")
    assert(toggle_btn)
    assert_equal("button", toggle_btn["type"])
    assert_equal("toggleMapBtn", toggle_btn["data-map-target"])
    assert_equal("false", toggle_btn["aria-expanded"])
    assert_equal("test_map", toggle_btn["aria-controls"])
  end

  def test_renders_toggle_button_with_show_and_hide_labels
    html = render_component(Components::FormLocationMap.new)

    assert_html(html, "span.map-show")
    assert_html(html, "span.map-hide")
  end

  def test_renders_clear_button
    html = render_component(Components::FormLocationMap.new)
    doc = Nokogiri::HTML(html)

    clear_btn = doc.at_css("button.map-clear")
    assert(clear_btn)
    assert_equal("button", clear_btn["type"])
    assert_equal("mapClearBtn", clear_btn["data-map-target"])
  end

  def test_uses_default_location_format_without_user
    html = render_component(Components::FormLocationMap.new)
    doc = Nokogiri::HTML(html)
    map_div = doc.at_css("div.form-map")

    assert_equal("postal", map_div["data-location-format"])
  end

  def test_uses_user_location_format_when_provided
    user = users(:rolf)
    user.update!(location_format: "scientific")

    html = render_component(
      Components::FormLocationMap.new(user: user)
    )
    doc = Nokogiri::HTML(html)
    map_div = doc.at_css("div.form-map")

    assert_equal("scientific", map_div["data-location-format"])
  end
end

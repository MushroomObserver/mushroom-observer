# frozen_string_literal: true

require "test_helper"

class BoundsHiddenFieldsTest < UnitTestCase
  include ComponentTestHelper

  def test_renders_all_six_bound_fields
    html = render_component(Components::BoundsHiddenFields.new)

    %w[north south east west low high].each do |key|
      assert_html(html, "input[type='hidden'][name='location[#{key}]']")
    end
  end

  def test_renders_with_default_geocode_controller_targets
    html = render_component(Components::BoundsHiddenFields.new)

    assert_html(html, "input[data-geocode-target='northInput']")
    assert_html(html, "input[data-geocode-target='southInput']")
    assert_html(html, "input[data-geocode-target='eastInput']")
    assert_html(html, "input[data-geocode-target='westInput']")
    assert_html(html, "input[data-geocode-target='lowInput']")
    assert_html(html, "input[data-geocode-target='highInput']")
  end

  def test_renders_with_custom_target_controller
    html = render_component(
      Components::BoundsHiddenFields.new(target_controller: :map)
    )

    assert_html(html, "input[data-map-target='northInput']")
    assert_html(html, "input[data-map-target='southInput']")
  end

  def test_renders_with_location_values
    location = locations(:burbank)
    html = render_component(
      Components::BoundsHiddenFields.new(location: location)
    )

    doc = Nokogiri::HTML(html)

    north_input = doc.at_css("input[name='location[north]']")
    assert_equal(location.north.to_s, north_input["value"])

    south_input = doc.at_css("input[name='location[south]']")
    assert_equal(location.south.to_s, south_input["value"])

    east_input = doc.at_css("input[name='location[east]']")
    assert_equal(location.east.to_s, east_input["value"])

    west_input = doc.at_css("input[name='location[west]']")
    assert_equal(location.west.to_s, west_input["value"])
  end

  def test_renders_without_location_with_empty_values
    html = render_component(Components::BoundsHiddenFields.new)
    doc = Nokogiri::HTML(html)

    north_input = doc.at_css("input[name='location[north]']")
    assert_nil(north_input["value"])
  end
end

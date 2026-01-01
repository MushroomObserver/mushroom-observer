# frozen_string_literal: true

require "test_helper"

class BoundsHiddenFieldsTest < ComponentTestCase

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

    assert_html(html, "input[name='location[north]']",
                attribute: { value: location.north.to_s })
    assert_html(html, "input[name='location[south]']",
                attribute: { value: location.south.to_s })
    assert_html(html, "input[name='location[east]']",
                attribute: { value: location.east.to_s })
    assert_html(html, "input[name='location[west]']",
                attribute: { value: location.west.to_s })
  end

  def test_renders_without_location_with_empty_values
    html = render_component(Components::BoundsHiddenFields.new)

    # Hidden fields should have no value attribute when location is nil
    assert_no_html(html, "input[name='location[north]'][value]")
  end
end

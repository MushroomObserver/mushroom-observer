# frozen_string_literal: true

require("test_helper")

class Components::Badge::CountTest < ComponentTestCase
  def test_renders_count
    html = render_badge(count: 3)

    assert_html(html, ".count-badge", text: "3")
  end

  def test_renders_zero
    html = render_badge(count: 0)

    assert_html(html, ".count-badge", text: "0")
  end

  def test_has_no_data_attributes
    html = render_badge(count: 5)

    assert_no_html(html, "[data-controller]")
  end

  def test_default_object_type_is_observation
    html = render_badge(count: 5)

    tooltip = :count_badge_tooltip.t(type: :observation.t.upcase_first)
    assert_html(html, ".count-badge[title='#{tooltip}']" \
                      "[data-tooltip-target='tip']")
  end

  def test_object_type_herbarium_record
    html = render_badge(count: 5, object_type: :herbarium_record)

    tooltip = :count_badge_tooltip.t(type: :herbarium_record.t.upcase_first)
    assert_html(html, ".count-badge[title='#{tooltip}']")
  end

  def test_default_fill_is_solid
    html = render_badge(count: 5)

    assert_no_html(html, ".badge-outline")
  end

  def test_fill_outline
    html = render_badge(count: 5, fill: :outline)

    assert_html(html, ".count-badge.badge-outline", text: "5")
  end

  # `.badge-#{variant}` is Bootstrap's color class (styling
  # abstraction -- the class name IS this prop's contract).
  def test_default_variant_is_secondary
    html = render_badge(count: 5)

    assert_html(html, ".count-badge.badge-secondary", text: "5")
  end

  def test_variant_overrides_default_color
    html = render_badge(count: 5, variant: :danger)

    assert_html(html, ".count-badge.badge-danger", text: "5")
    assert_no_html(html, ".badge-secondary")
  end

  private

  def render_badge(count:, object_type: :observation, fill: :solid,
                   variant: :secondary)
    render(Components::Badge.new(type: :count, count: count,
                                 object_type: object_type, fill: fill,
                                 variant: variant))
  end
end

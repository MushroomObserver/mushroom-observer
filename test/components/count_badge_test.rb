# frozen_string_literal: true

require("test_helper")

class Components::CountBadgeTest < ComponentTestCase
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

  def test_default_type_is_observation
    html = render_badge(count: 5)

    tooltip = :count_badge_tooltip.t(type: :observation.t.upcase_first)
    assert_html(html, ".count-badge[title='#{tooltip}']" \
                      "[data-tooltip-target='tip']")
  end

  def test_type_herbarium_record
    html = render_badge(count: 5, type: :herbarium_record)

    tooltip = :count_badge_tooltip.t(type: :herbarium_record.t.upcase_first)
    assert_html(html, ".count-badge[title='#{tooltip}']")
  end

  def test_default_variant_is_solid
    html = render_badge(count: 5)

    assert_no_html(html, ".badge-outline")
  end

  def test_variant_outline
    html = render_badge(count: 5, variant: :outline)

    assert_html(html, ".count-badge.badge-outline", text: "5")
  end

  private

  def render_badge(count:, type: :observation, variant: :solid)
    render(Components::CountBadge.new(count: count, type: type,
                                      variant: variant))
  end
end

# frozen_string_literal: true

require("test_helper")

class LinkIconTest < ComponentTestCase
  def test_glyph_only
    html = render_icon(type: :globe)

    assert_html(html, "svg.mo-icon.mo-icon-globe")
    # No <title> element when title is absent — just the bare glyph.
    assert_no_html(html, "svg > title")
  end

  def test_underscored_type_becomes_kebab_case_class
    html = render_icon(type: :chevron_down)

    assert_html(html, "svg.mo-icon.mo-icon-chevron-down")
  end

  def test_unknown_type_renders_nothing
    html = render_icon(type: :bogus_not_a_real_icon)

    # Unknown icon type silently emits nothing — matches the legacy
    # `link_icon` helper's `return "" unless LINK_ICON_INDEX[type]`.
    assert_equal("", html)
  end

  def test_renders_nothing_when_sprite_unavailable
    Components::Icon.send(:remove_const, :SPRITE_AVAILABLE)
    Components::Icon.const_set(:SPRITE_AVAILABLE, false)

    assert_equal("", render_icon(type: :globe))
  ensure
    Components::Icon.send(:remove_const, :SPRITE_AVAILABLE)
    Components::Icon.const_set(:SPRITE_AVAILABLE, true)
  end

  def test_title_adds_tooltip_and_accessible_title_element
    html = render_icon(type: :edit, title: :edit.ti, class: "text-primary")

    assert_html(html,
                "svg.mo-icon.mo-icon-edit.text-primary" \
                "[title='#{:edit.ti}'][data-tooltip-target='tip']")
    # Native SVG <title> child so the icon-only link has an
    # accessible name for screen readers.
    assert_html(html, "svg > title", text: :edit.ti)
  end

  def test_caller_data_attrs_merge_with_tooltip_data
    html = render_icon(type: :globe, title: "Tooltip text",
                       data: { other: "v" })

    # Tooltip target still present alongside caller's custom data attr.
    assert_html(html, "svg[data-tooltip-target='tip'][data-other='v']")
  end

  def test_extra_attrs_passed_through
    html = render_icon(type: :globe, id: "my_icon")

    assert_html(html, "svg#my_icon.mo-icon-globe")
  end

  private

  def render_icon(**)
    render(Components::Icon.new(**))
  end
end

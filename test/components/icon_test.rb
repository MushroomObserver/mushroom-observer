# frozen_string_literal: true

require("test_helper")

class LinkIconTest < ComponentTestCase
  def test_glyph_only
    html = render(Components::Icon.new(type: :globe))

    assert_html(html, "span.glyphicon.glyphicon-globe.link-icon")
    # No sr-only inner span when title is absent — just the bare glyph.
    assert_no_html(html, "span.sr-only")
  end

  def test_unknown_type_renders_nothing
    html = render(Components::Icon.new(type: :bogus_not_a_real_icon))

    # Unknown icon type silently emits nothing — matches the legacy
    # `link_icon` helper's `return "" unless LINK_ICON_INDEX[type]`.
    assert_equal("", html)
  end

  def test_title_adds_tooltip_and_sr_only_label
    html = render(Components::Icon.new(
                    type: :edit, title: :EDIT.l,
                    class: "text-primary"
                  ))

    assert_html(html,
                "span.glyphicon-edit.link-icon.text-primary" \
                "[title='#{:EDIT.l}'][data-toggle='tooltip']")
    # Screen-reader label so the icon-only link has an accessible name.
    assert_html(html, "span.sr-only", text: :EDIT.l)
  end

  def test_caller_data_attrs_merge_with_tooltip_data
    html = render(Components::Icon.new(
                    type: :globe, title: "Tooltip text",
                    data: { other: "v" }
                  ))

    # Tooltip toggle still present alongside caller's custom data attr.
    assert_html(html, "span[data-toggle='tooltip'][data-other='v']")
  end

  def test_extra_attrs_passed_through
    html = render(Components::Icon.new(
                    type: :globe, id: "my_icon"
                  ))

    assert_html(html, "span#my_icon.glyphicon-globe")
  end
end

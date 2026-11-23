# frozen_string_literal: true

require("test_helper")

class ActiveLinkTest < ComponentTestCase
  def test_renders_link_with_nav_active_stimulus_data_attrs
    html = render_active(content: "Home", path: "/")

    assert_html(html, "a[href='/']" \
                      "[data-nav-active-target='link']" \
                      "[data-action='nav-active#navigate']",
                text: "Home")
  end

  def test_caller_data_attrs_deep_merge_with_stimulus_attrs
    html = render_active(content: "Home", path: "/", data: { my_attr: "v" })

    # Stimulus wiring + caller's custom data both on the anchor.
    assert_html(html, "a[data-nav-active-target='link']" \
                      "[data-my-attr='v']")
  end

  def test_caller_class_passes_through
    html = render_active(content: "Home", path: "/", class: "list-group-item")

    assert_html(html, "a.list-group-item[href='/']")
  end

  def test_html_safe_content_not_escaped
    safe_text = "<b>bold</b>".html_safe
    html = render_active(content: safe_text, path: "/")

    assert_html(html, "a b", text: "bold")
  end

  def test_icon_renders_svg_and_hides_content_as_sr_only
    html = render_active(content: "Home", path: "/", icon: :globe)

    assert_html(html, "a svg.mo-icon-globe")
    assert_html(html, "a .sr-only", text: "Home")
  end

  def test_icon_adds_hover_tooltip
    html = render_active(content: "Home", path: "/", icon: :globe)

    assert_html(html, "a[title='Home'][data-tooltip-target='tip']")
  end

  def test_icon_keeps_nav_active_stimulus_data_attrs
    html = render_active(content: "Home", path: "/", icon: :globe)

    assert_html(html, "a[data-nav-active-target='link']" \
                      "[data-action='nav-active#navigate']")
  end

  def test_no_icon_renders_plain_text_with_no_tooltip
    html = render_active(content: "Home", path: "/")

    assert_no_html(html, "svg")
    assert_no_html(html, "a[data-tooltip-target]")
  end

  private

  def render_active(**)
    render(Components::Link::Active.new(**))
  end
end

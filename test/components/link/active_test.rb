# frozen_string_literal: true

require("test_helper")

class ActiveLinkTest < ComponentTestCase
  def test_renders_link_with_nav_active_stimulus_data_attrs
    html = render(Components::Link::Active.new(content: "Home", path: "/"))

    assert_html(html, "a[href='/']" \
                      "[data-nav-active-target='link']" \
                      "[data-action='nav-active#navigate']",
                text: "Home")
  end

  def test_caller_data_attrs_deep_merge_with_stimulus_attrs
    html = render(Components::Link::Active.new(
                    content: "Home", path: "/", data: { my_attr: "v" }
                  ))

    # Stimulus wiring + caller's custom data both on the anchor.
    assert_html(html, "a[data-nav-active-target='link']" \
                      "[data-my-attr='v']")
  end

  def test_caller_class_passes_through
    html = render(Components::Link::Active.new(
                    content: "Home", path: "/", class: "list-group-item"
                  ))

    assert_html(html, "a.list-group-item[href='/']")
  end

  def test_html_safe_content_not_escaped
    safe_text = "<b>bold</b>".html_safe
    html = render(Components::Link::Active.new(content: safe_text, path: "/"))

    assert_html(html, "a b", text: "bold")
  end
end

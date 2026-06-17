# frozen_string_literal: true

require("test_helper")

class IconLinkTest < ComponentTestCase
  def test_plain_icon_link
    html = render(Components::Link::Icon.new(
                    "Edit", "/foo", icon: :edit
                  ))

    # Outer anchor: href, tooltip title, icon-link class, and the
    # data-toggle/data-title pair the bootstrap tooltip plugin reads.
    assert_html(html, "a[href='/foo'][title='Edit'].icon-link" \
                      "[data-toggle='tooltip'][data-title='Edit']")
    # Icon glyph + screen-reader-only label inside the anchor.
    assert_html(html, "a span.glyphicon-edit")
    assert_html(html, "a span.sr-only", text: "Edit")
  end

  def test_blank_text_renders_nothing
    # Matches legacy `icon_link_to` — silent no-op when text is nil.
    html = render(Components::Link::Icon.new(nil, "/x", icon: :edit))

    assert_equal("", html)
  end

  def test_no_icon_falls_back_to_plain_link
    html = render(Components::Link::Icon.new("Label", "/x"))

    # Without an `:icon`, render as a plain link with the text.
    # (The legacy helper had a typo here referencing undefined `link`
    # — fixed in the component to render correctly.)
    assert_html(html, "a[href='/x']", text: "Label")
    # No icon span when no icon was passed.
    assert_no_html(html, "a span.glyphicon")
  end

  def test_show_text_replaces_sr_only_with_visible_label
    html = render(Components::Link::Icon.new(
                    "Delete", "/d", icon: :delete, show_text: true
                  ))

    assert_no_html(html, "a span.sr-only")
    assert_html(html, "a span.font-weight-bold", text: "Delete")
  end

  def test_stateful_renders_active_icon_and_label
    html = render(Components::Link::Icon.new(
                    "Subscribe", "/s",
                    icon: :tracking,
                    active_icon: :check, active_content: "Subscribed"
                  ))

    # Both icons + both labels render; the active pair carries the
    # `active-icon` / `active-label` modifier classes the JS toggles
    # on/off via the bootstrap tooltip's data-active-title swap.
    assert_html(html, "a span.glyphicon-bullhorn")
    assert_html(html, "a span.glyphicon-ok-circle.active-icon")
    assert_html(html, "a span.sr-only", text: "Subscribe")
    assert_html(html, "a span.sr-only.active-label", text: "Subscribed")
    # data-active-title flips to the active text on toggle.
    assert_html(html, "a[data-active-title='Subscribed']")
  end

  def test_button_to_mode
    html = render(Components::Link::Icon.new(
                    "Delete", "/d", icon: :delete, button_to: true
                  ))

    # button_to wraps a button in a form; `role='button'` is added so
    # the form-styled `<button>` is announced as a button by AT.
    assert_html(html, "form[action='/d'] button[role='button']")
    assert_html(html, "form button span.glyphicon-remove-circle")
  end

  def test_extra_class_appends_to_icon_link
    html = render(Components::Link::Icon.new(
                    "Edit", "/x", icon: :edit, class: "extra-thing"
                  ))

    # Caller's `:class` deep-merges with the default `icon-link` class.
    assert_html(html, "a.icon-link.extra-thing")
  end

  def test_arbitrary_data_attrs_deep_merge_onto_link
    html = render(Components::Link::Icon.new(
                    "X", "/x",
                    icon: :edit, data: { my_attr: "v" }
                  ))

    # `data: { ... }` from the caller deep_merges with the tooltip
    # data attrs, so both the tooltip wiring AND the caller's custom
    # attrs end up on the anchor.
    assert_html(html, "a[data-my-attr='v'][data-toggle='tooltip']")
  end

  # `tab:` shortcut — derive content / path / opts from a Tab PORO so
  # ERB and Phlex callers don't have to destructure `tab.to_a`
  # themselves. Equivalent to passing `tab.title, tab.path,
  # **tab.html_options` positionally.
  def test_tab_kwarg_derives_content_path_opts
    project = projects(:eol_project)
    tab = Tab::Project::Summary.new(project: project)

    html = render(Components::Link::Icon.new(tab: tab))

    assert_html(html, "a[href='#{tab.path}']", text: tab.title)
  end
end

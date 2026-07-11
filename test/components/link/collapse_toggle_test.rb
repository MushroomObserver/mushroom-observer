# frozen_string_literal: true

require("test_helper")

class CollapseToggleLinkTest < ComponentTestCase
  def test_renders_anchor_pointing_to_target
    html = render_it

    assert_html(html, "a[href='#help_foo']")
  end

  def test_role_button
    html = render_it

    assert_html(html, "a[role='button']")
  end

  def test_data_toggle_collapse
    html = render_it

    assert_html(html, "a[data-toggle='collapse']")
  end

  def test_aria_controls_matches_target_id
    html = render_it

    assert_html(html, "a[aria-controls='help_foo']")
  end

  def test_aria_expanded_true_when_not_collapsed
    html = render_it(collapsed: false)

    assert_html(html, "a[aria-expanded='true']")
  end

  def test_aria_expanded_false_when_collapsed
    html = render_it(collapsed: true)

    assert_html(html, "a[aria-expanded='false']")
  end

  def test_collapsed_false_omits_collapsed_class
    html = render_it(collapsed: false)

    assert_no_html(html, "a.collapsed")
  end

  def test_collapsed_true_adds_collapsed_class
    html = render_it(collapsed: true)

    assert_html(html, "a.collapsed")
  end

  def test_extra_class_applied
    html = render_it(class: "info-collapse-trigger")

    assert_html(html, "a.info-collapse-trigger")
  end

  def test_yields_block_content
    html = render(
      Class.new(Components::Base) do
        def view_template
          render(::Components::Link::CollapseToggle.new(
                   target_id: "t"
                 )) { span { plain("inner") } }
        end
      end.new
    )

    assert_html(html, "a > span", text: "inner")
  end

  def test_extra_data_attrs_merged
    html = render_it(data: { target: "#some_target" })

    assert_html(html, "a[data-target='#some_target']")
    assert_html(html, "a[data-toggle='collapse']")
  end

  def test_fallback_href_sets_href_and_adds_data_target
    html = render_it(fallback_href: "/things/new")

    # href is the navigation fallback, not the collapse anchor
    assert_html(html, "a[href='/things/new']")
    # Bootstrap reads data-target before href; both must be present
    assert_html(html, "a[data-target='#help_foo']")
    assert_html(html, "a[data-toggle='collapse']")
  end

  def test_without_fallback_href_href_is_anchor
    html = render_it

    assert_html(html, "a[href='#help_foo']")
    assert_no_html(html, "a[data-target]")
  end

  def test_button_variant_adds_btn_classes
    html = render_it(button: :link)

    assert_html(html, "a[data-toggle='collapse']")
  end

  def test_default_button_variant_adds_btn_default
    html = render_it(button: :default)

    assert_html(html, "a[data-toggle='collapse']")
  end

  def test_size_adds_btn_size_class_alongside_button
    html = render_it(button: :link, size: :xs)

    assert_html(html, "a[data-toggle='collapse']")
  end

  def test_icon_kwarg_renders_icon_in_link
    html = render_it(icon: :info)

    assert_html(html, "a span.glyphicon")
  end

  def test_icon_title_forwarded_to_icon
    html = render_it(icon: :info, icon_title: "Help content")

    assert_html(html, "a span.sr-only", text: "Help content")
  end

  def test_icon_title_defaults_to_closed_text
    html = render_it(icon: :plus, closed_text: "Show more")

    assert_html(html, "a span.sr-only", text: "Show more")
  end

  def test_open_text_renders_collapse_toggle_open_span
    html = render_it(open_text: "Hide details")

    assert_html(html, "a span.collapse-toggle-open", text: "Hide details")
  end

  def test_closed_text_renders_collapse_toggle_closed_span
    html = render_it(closed_text: "Show details")

    assert_html(html, "a span.collapse-toggle-closed", text: "Show details")
  end

  def test_no_content_kwargs_renders_empty_link
    html = render_it

    assert_no_html(html, "a span")
  end

  private

  def render_it(target_id: "help_foo", **)
    render(Components::Link::CollapseToggle.new(target_id:, **))
  end
end

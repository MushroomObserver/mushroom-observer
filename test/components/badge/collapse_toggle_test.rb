# frozen_string_literal: true

require("test_helper")

class Components::Badge::CollapseToggleTest < ComponentTestCase
  def test_renders_anchor_pointing_to_target_with_value_as_text
    html = render_it

    assert_html(html, "a[href='#pane_foo']", text: "MCP")
  end

  def test_renders_open_and_closed_text_spans
    html = render_it

    assert_html(html, "a .collapse-toggle-closed", text: "MCP")
    assert_html(html, "a .collapse-toggle-open", text: :hide.ti)
  end

  def test_open_text_overridable
    html = render_it(open_text: "Close")

    assert_html(html, "a .collapse-toggle-open", text: "Close")
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

    assert_html(html, "a[aria-controls='pane_foo']")
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

  # Badge is a styling-abstraction component -- the class output is
  # the thing under test here, same exception as Badge::ID's test.
  # rubocop:disable-next MO/NoCosmeticClassAssertion
  def test_caller_class_applied
    html = render_it(class: "text-uppercase")

    assert_html(html, "a.text-uppercase")
  end

  # rubocop:disable-next MO/NoCosmeticClassAssertion
  def test_size_adds_badge_size_class
    html = render_it(size: :xl)

    assert_html(html, "a.badge-xl")
  end

  def test_extra_data_attrs_merged
    html = render_it(data: { tooltip_target: "tip" })

    assert_html(html, "a[data-tooltip-target='tip']")
    assert_html(html, "a[data-toggle='collapse']")
  end

  # Caller-supplied aria attrs merge alongside the computed
  # expanded:/controls: pair, instead of being silently dropped.
  def test_extra_aria_attrs_merged
    html = render_it(aria: { label: "Toggle details" })

    assert_html(html, "a[aria-label='Toggle details']")
    assert_html(html, "a[aria-expanded='false']")
    assert_html(html, "a[aria-controls='pane_foo']")
  end

  def test_fallback_href_sets_href_and_adds_data_target
    html = render_it(fallback_href: "/external_links/1")

    # href is the navigation fallback, not the collapse anchor
    assert_html(html, "a[href='/external_links/1']")
    # Bootstrap reads data-target before href; both must be present
    assert_html(html, "a[data-target='#pane_foo']")
    assert_html(html, "a[data-toggle='collapse']")
  end

  def test_without_fallback_href_href_is_anchor
    html = render_it

    assert_html(html, "a[href='#pane_foo']")
    assert_no_html(html, "a[data-target]")
    assert_no_html(html, "a[data-controller]")
  end

  private

  def render_it(target_id: "pane_foo", value: "MCP", size: :xl, **)
    render(Components::Badge::CollapseToggle.new(
             target_id:, value:, size:, **
           ))
  end
end

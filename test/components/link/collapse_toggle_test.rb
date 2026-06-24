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

  private

  def render_it(target_id: "help_foo", **)
    render(Components::Link::CollapseToggle.new(target_id:, **))
  end
end

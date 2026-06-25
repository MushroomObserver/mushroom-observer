# frozen_string_literal: true

require("test_helper")

# Proves block form ≡ kwarg form for `Link::CollapseToggle`.
# Commit af428c1e0 introduced block form; commit a8810a140 converted
# callers to kwargs. Both forms are still supported, so we render
# each and assert the resulting `<a>` subtrees are identical.
class Components::Link::CollapseToggleParityTest < ComponentTestCase
  # Search-bar help toggle (icon: :info with title).
  def test_icon_with_title_kwarg_matches_block_form
    old_html = render_block_form(
      target_id: "search_bar_help",
      icon: :info,
      icon_title: :search_bar_help.t
    )
    new_html = render_kwarg_form(
      target_id: "search_bar_help",
      icon: :info,
      icon_title: :search_bar_help.t
    )

    assert_html_element_equivalent(old_html, new_html,
                                   selector: "a",
                                   label: "info_icon_with_title")
  end

  # Search-bar form toggle (icon: :plus with title).
  def test_different_icon_with_title_kwarg_matches_block_form
    old_html = render_block_form(
      target_id: "search_nav_form",
      icon: :plus,
      icon_title: :search_bar_more_options.l
    )
    new_html = render_kwarg_form(
      target_id: "search_nav_form",
      icon: :plus,
      icon_title: :search_bar_more_options.l
    )

    assert_html_element_equivalent(old_html, new_html,
                                   selector: "a",
                                   label: "plus_icon_with_title")
  end

  # Search-bar "fewer options" toggle (icon: :minus, starts open).
  def test_minus_icon_with_title_kwarg_matches_block_form
    old_html = render_block_form(
      target_id: "search_bar_elements",
      collapsed: false,
      button: :btn_link,
      icon: :minus,
      icon_title: :search_bar_fewer_options.l
    )
    new_html = render_kwarg_form(
      target_id: "search_bar_elements",
      collapsed: false,
      button: :btn_link,
      icon: :minus,
      icon_title: :search_bar_fewer_options.l
    )

    assert_html_element_equivalent(old_html, new_html,
                                   selector: "a",
                                   label: "minus_icon_with_title")
  end

  # API-keys cancel toggle (icon: :cancel, starts open, :default btn).
  def test_cancel_icon_with_title_kwarg_matches_block_form
    old_html = render_block_form(
      target_id: "api_keys_cancel",
      collapsed: false,
      button: :default,
      icon: :cancel,
      icon_title: :CANCEL.l
    )
    new_html = render_kwarg_form(
      target_id: "api_keys_cancel",
      collapsed: false,
      button: :default,
      icon: :cancel,
      icon_title: :CANCEL.l
    )

    assert_html_element_equivalent(old_html, new_html,
                                   selector: "a",
                                   label: "cancel_icon_with_title")
  end

  # Contribution-legend toggle (icon only, no title).
  def test_icon_only_no_title_kwarg_matches_block_form
    old_html = render_block_form(
      target_id: "contribution_legend",
      button: :btn_link,
      size: :xs,
      icon: :info_circle
    )
    new_html = render_kwarg_form(
      target_id: "contribution_legend",
      button: :btn_link,
      size: :xs,
      icon: :info_circle
    )

    assert_html_element_equivalent(old_html, new_html,
                                   selector: "a",
                                   label: "info_circle_icon_no_title")
  end

  private

  # Renders a CollapseToggle using the old block API. `icon:` and
  # `icon_title:` are extracted so the block can render them manually
  # via Components::Icon — the original call pattern before kwargs
  # were added. Remaining opts are forwarded to the link component.
  def render_block_form(target_id:, collapsed: true, **opts)
    icon_type  = opts.delete(:icon)
    icon_title = opts.delete(:icon_title)
    t = target_id
    c = collapsed
    o = opts
    render(Class.new(Components::Base) do
      define_method(:view_template) do
        render(::Components::Link::CollapseToggle.new(
                 target_id: t, collapsed: c, **o
               )) do
          render(::Components::Icon.new(
                   type: icon_type, title: icon_title
                 ))
        end
      end
    end.new)
  end

  def render_kwarg_form(target_id:, collapsed: true, **)
    render(::Components::Link::CollapseToggle.new(
             target_id:, collapsed:, **
           ))
  end
end

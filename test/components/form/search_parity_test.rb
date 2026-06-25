# frozen_string_literal: true

require("test_helper")

# Pre-refactor search-bar toggle in `Components::Form::Search`.
# The old implementation used `Components::Button` (a `<button>`)
# with a block rendering the icon; the new code uses
# `Link::CollapseToggle` (an `<a role="button">`).
class OldSearchBarToggle < Components::Base
  def view_template
    render(::Components::Button.new(
             variant: :btn_link,
             class: "navbar-link px-2",
             data: { toggle: "collapse",
                     search_type_target: "barToggle",
                     target: "#search_bar_elements" },
             aria: { expanded: "false",
                     controls: "search_bar_elements" }
           )) do
      render(::Components::Icon.new(
               type: :minus,
               title: :search_bar_fewer_options.l
             ))
    end
  end
end

# Documents the migration of `render_search_bar_toggle` in
# `Components::Form::Search` from `Components::Button` with a block
# to `Link::CollapseToggle`.
#
# Intentional changes:
#   - Element type: `<button>` → `<a role="button">`
#   - `data-target="#search_bar_elements"` → `href="#search_bar_elements"`
#   - `aria-expanded="false"` (wrong — bar starts open) →
#     `aria-expanded="true"` (correct for `collapsed: false`)
#
# Behavioral wiring (data-toggle, Stimulus target, icon) is preserved.
class Components::Form::SearchParityTest < ComponentTestCase
  def test_search_bar_toggle_preserves_behavioral_wiring
    old_html = render(OldSearchBarToggle.new)
    new_html = render(Components::Link::CollapseToggle.new(
                        target_id: "search_bar_elements",
                        collapsed: false,
                        icon: :minus,
                        icon_title: :search_bar_fewer_options.l,
                        button: :btn_link,
                        class: "navbar-link px-2",
                        data: { search_type_target: "barToggle" }
                      ))

    # Collapse wiring and Stimulus target in both.
    assert_html(old_html,
                "button[data-toggle='collapse']" \
                "[data-search-type-target='barToggle']" \
                "[aria-controls='search_bar_elements']")
    assert_html(new_html,
                "a[data-toggle='collapse']" \
                "[data-search-type-target='barToggle']" \
                "[aria-controls='search_bar_elements']")

    # Icon subtree identical in both.
    assert_html(old_html, "span.glyphicon")
    assert_html(new_html, "span.glyphicon")
    assert_html_element_equivalent(old_html, new_html,
                                   selector: "span.glyphicon",
                                   label: "search_bar_toggle_icon")

    # Intentional changes: element type, collapse pointer, aria-expanded.
    # Old button had a hardcoded false even though the bar starts open.
    assert_html(old_html,
                "button[data-target='#search_bar_elements']" \
                "[aria-expanded='false']")
    assert_html(new_html,
                "a[href='#search_bar_elements'][role='button']" \
                "[aria-expanded='true']")
    assert_no_html(new_html, "button")
  end
end

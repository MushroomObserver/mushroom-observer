# frozen_string_literal: true

require("test_helper")

# Pre-refactor help toggle — raw Phlex `button(...)` call.
# Wrapped in Components::Base so it can call Phlex element methods.
class OldHelpToggle < Components::Base
  prop :visible, _Boolean, default: true

  def view_template
    button(type: "button",
           class: class_names("btn", "btn-link", "navbar-link",
                              "px-2", "d-none" => !@visible),
           data: { toggle: "collapse",
                   search_type_target: "helpToggle",
                   target: "#search_bar_help" },
           aria: { expanded: "false",
                   controls: "search_bar_help" }) do
      render(::Components::Icon.new(type: :info,
                                    title: :search_bar_help.t))
    end
  end
end

# Pre-refactor form toggle — raw Phlex `button(...)` call.
class OldFormToggle < Components::Base
  prop :visible, _Boolean, default: true

  def view_template
    button(type: "button",
           class: class_names("btn", "btn-link", "navbar-link",
                              "px-2", "d-none" => !@visible),
           data: { toggle: "collapse",
                   search_type_target: "formToggle",
                   target: "#search_nav_form" },
           aria: { expanded: "false",
                   controls: "search_nav_form" }) do
      render(::Components::Icon.new(type: :plus,
                                    title: :search_bar_more_options.l))
    end
  end
end

# Documents the migration of `render_help_toggle` and
# `render_form_toggle` in `Views::Layouts::TopNav::SearchBar`
# from raw Phlex `button(...)` calls to `Link::CollapseToggle`.
#
# Intentional element change: `<button>` → `<a role="button">`.
# Behavioral wiring (data-toggle, aria-controls, icon) is preserved.
class Views::Layouts::TopNav
  class SearchBarParityTest < ComponentTestCase
    # --- Help toggle ---

    def test_help_toggle_preserves_behavioral_wiring
      old_html = render(OldHelpToggle.new(visible: true))
      new_html = render(Components::Link::CollapseToggle.new(
                          target_id: "search_bar_help",
                          icon: :info,
                          icon_title: :search_bar_help.t,
                          class: "btn btn-link navbar-link px-2",
                          data: { search_type_target: "helpToggle" }
                        ))

      # Collapse wiring and Stimulus target preserved in both.
      assert_html(old_html,
                  "button[data-toggle='collapse']" \
                  "[data-search-type-target='helpToggle']" \
                  "[aria-controls='search_bar_help']" \
                  "[aria-expanded='false']")
      assert_html(new_html,
                  "a[data-toggle='collapse']" \
                  "[data-search-type-target='helpToggle']" \
                  "[aria-controls='search_bar_help']" \
                  "[aria-expanded='false']")

      # Icon present in both; icon subtree is identical.
      assert_html(old_html, "span.glyphicon")
      assert_html(new_html, "span.glyphicon")
      assert_html_element_equivalent(old_html, new_html,
                                     selector: "span.glyphicon",
                                     label: "help_toggle_icon")

      # Intentional change: element type button → a, data-target → href.
      assert_html(old_html, "button[data-target='#search_bar_help']")
      assert_html(new_html, "a[href='#search_bar_help'][role='button']")
      assert_no_html(new_html, "button")
    end

    # --- Form toggle ---

    def test_form_toggle_preserves_behavioral_wiring
      old_html = render(OldFormToggle.new(visible: true))
      new_html = render(Components::Link::CollapseToggle.new(
                          target_id: "search_nav_form",
                          icon: :plus,
                          icon_title: :search_bar_more_options.l,
                          class: "btn btn-link navbar-link px-2",
                          data: { search_type_target: "formToggle" }
                        ))

      # Collapse wiring and Stimulus target preserved in both.
      assert_html(old_html,
                  "button[data-toggle='collapse']" \
                  "[data-search-type-target='formToggle']" \
                  "[aria-controls='search_nav_form']" \
                  "[aria-expanded='false']")
      assert_html(new_html,
                  "a[data-toggle='collapse']" \
                  "[data-search-type-target='formToggle']" \
                  "[aria-controls='search_nav_form']" \
                  "[aria-expanded='false']")

      # Icon present in both; icon subtree is identical.
      assert_html(old_html, "span.glyphicon")
      assert_html(new_html, "span.glyphicon")
      assert_html_element_equivalent(old_html, new_html,
                                     selector: "span.glyphicon",
                                     label: "form_toggle_icon")

      # Intentional change: element type button → a, data-target → href.
      assert_html(old_html, "button[data-target='#search_nav_form']")
      assert_html(new_html, "a[href='#search_nav_form'][role='button']")
      assert_no_html(new_html, "button")
    end
  end
end

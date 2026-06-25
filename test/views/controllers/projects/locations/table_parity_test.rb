# frozen_string_literal: true

require("test_helper")

# Old `render_chevron` in `Projects::Locations::Table` used
# `link_to("javascript:void(0)", data-target: "#...", ...)`.
# After this PR it uses `Link::CollapseToggle`, which replaces
# the JS-void href with a real anchor and drops data-target.
class OldChevron < Components::Base
  def view_template
    link_to(
      "javascript:void(0)",
      role: :button,
      class: "panel-collapse-trigger collapsed",
      data: { toggle: "collapse",
              target: "#target_subs_42" },
      aria: { expanded: false,
              controls: "target_subs_42" }
    ) do
      render(::Components::Icon.new(
               type: :chevron_down,
               title: :OPEN.l,
               html_class: "active-icon"
             ))
      render(::Components::Icon.new(type: :chevron_up, title: :CLOSE.l))
    end
  end
end

class NewChevron < Components::Base
  def view_template
    render(::Components::Link::CollapseToggle.new(
             target_id: "target_subs_42",
             collapsed: true,
             class: "panel-collapse-trigger"
           )) do
      render(::Components::Icon.new(
               type: :chevron_down,
               title: :OPEN.l,
               html_class: "active-icon"
             ))
      render(::Components::Icon.new(type: :chevron_up, title: :CLOSE.l))
    end
  end
end

module Views::Controllers::Projects::Locations
  class TableParityTest < ComponentTestCase
    def test_chevron_trigger_parity
      old_html = render(OldChevron.new)
      new_html = render(NewChevron.new)

      # Collapse wiring and ARIA preserved in both.
      [old_html, new_html].each do |html|
        assert_html(html, "a[role='button']" \
                          "[data-toggle='collapse']" \
                          "[aria-expanded='false']" \
                          "[aria-controls='target_subs_42']")
        assert_html(html, "a.panel-collapse-trigger.collapsed")
      end

      # Old linked to javascript:void(0) + data-target for collapse.
      # New links directly to anchor href — no-JS fallback scrolls
      # to the section; JS intercepts via data-toggle.
      assert_html(old_html,
                  "a[href='javascript:void(0)']" \
                  "[data-target='#target_subs_42']")
      assert_html(new_html, "a[href='#target_subs_42']")
      assert_no_html(new_html, "[data-target]")

      # Both icons are identical (block content preserved).
      assert_html_element_equivalent(
        old_html, new_html,
        selector: "span.glyphicon-chevron-down",
        label: "chevron_down_icon"
      )
      assert_html_element_equivalent(
        old_html, new_html,
        selector: "span.glyphicon-chevron-up",
        label: "chevron_up_icon"
      )
    end
  end
end
